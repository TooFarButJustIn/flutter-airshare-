import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../models/device_model.dart';

class TransferService with ChangeNotifier {
  static const int CHUNK_SIZE = 64 * 1024; // 64KB chunks
  static const int TIMEOUT_SECONDS = 30;

  final Map<String, TransferProgress> _activeTransfers = {};
  final Map<String, Socket> _activeSockets = {};
  ServerSocket? _receiveServer;
  String? _downloadDirectory;

  Map<String, TransferProgress> get activeTransfers => Map.unmodifiable(_activeTransfers);

  Future<void> initialize(String downloadDirectory) async {
    _downloadDirectory = downloadDirectory;
    await Directory(downloadDirectory).create(recursive: true);
  }

  Stream<TransferProgress> sendFiles(List<FileItem> files, Device targetDevice) async* {
    final transferId = DateTime.now().millisecondsSinceEpoch.toString();
    Socket? socket;

    try {
      // Initial progress
      yield TransferProgress(
        fileId: transferId,
        fileName: 'Connecting...',
        totalBytes: 0,
        transferredBytes: 0,
        speed: 0,
        status: TransferStatus.connecting,
      );

      // Connect to target device with timeout
      socket = await Socket.connect(
        targetDevice.address,
        targetDevice.port,
      ).timeout(const Duration(seconds: TIMEOUT_SECONDS));

      _activeSockets[transferId] = socket;

      // Calculate total size
      int totalBytes = files.fold(0, (sum, file) => sum + file.size);

      final filesMetadata = <Map<String, dynamic>>[];
      for (final f in files) {
        filesMetadata.add({
          'name': f.name,
          'size': f.size,
          'mime_type': f.mimeType,
          'checksum': await _calculateFileChecksum(f.path),
        });
      }

      // Send transfer metadata
      final metadata = {
        'type': 'file_transfer',
        'version': '1.0',
        'transfer_id': transferId,
        'file_count': files.length,
        'total_size': totalBytes,
        'files': filesMetadata,
      };

      final metadataJson = jsonEncode(metadata);
      final metadataBytes = utf8.encode(metadataJson);

      // Send metadata length first, then metadata
      socket.add(_intToBytes(metadataBytes.length));
      socket.add(metadataBytes);
      await socket.flush();

      // Wait for acceptance with timeout
      final responseBytes = await socket.first.timeout(
          const Duration(seconds: TIMEOUT_SECONDS)
      );
      final responseJson = utf8.decode(responseBytes);
      final response = jsonDecode(responseJson);

      if (response['status'] != 'accepted') {
        throw Exception(response['message'] ?? 'Transfer rejected by target device');
      }

      // Send files
      int transferredBytes = 0;
      final startTime = DateTime.now();

      for (int fileIndex = 0; fileIndex < files.length; fileIndex++) {
        final file = files[fileIndex];
        final fileBytes = await File(file.path).readAsBytes();

        // Send file in chunks
        for (int offset = 0; offset < fileBytes.length; offset += CHUNK_SIZE) {
          final chunkEnd = (offset + CHUNK_SIZE < fileBytes.length)
              ? offset + CHUNK_SIZE
              : fileBytes.length;
          final chunk = fileBytes.sublist(offset, chunkEnd);

          socket.add(chunk);
          await socket.flush();

          transferredBytes += chunk.length;
          final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;
          final speed = elapsed > 0 ? (transferredBytes / elapsed).toDouble() : 0.0;

          final progress = TransferProgress(
            fileId: transferId,
            fileName: file.name,
            totalBytes: totalBytes,
            transferredBytes: transferredBytes,
            speed: speed,
            status: TransferStatus.transferring,
          );

          _activeTransfers[transferId] = progress;
          notifyListeners();
          yield progress;
        }
      }

      // Send completion signal
      socket.write('TRANSFER_COMPLETE\n');
      await socket.flush();
      await socket.close();

      final finalProgress = TransferProgress(
        fileId: transferId,
        fileName: 'Transfer complete',
        totalBytes: totalBytes,
        transferredBytes: totalBytes,
        speed: 0,
        status: TransferStatus.completed,
      );

      _activeTransfers[transferId] = finalProgress;
      notifyListeners();
      yield finalProgress;

    } catch (e) {
      final errorProgress = TransferProgress(
        fileId: transferId,
        fileName: 'Transfer failed',
        totalBytes: 0,
        transferredBytes: 0,
        speed: 0,
        status: TransferStatus.failed,
        error: e.toString(),
      );

      _activeTransfers[transferId] = errorProgress;
      notifyListeners();
      yield errorProgress;
    } finally {
      socket?.close();
      _activeSockets.remove(transferId);
    }
  }

  Future<void> startReceiveServer(int port) async {
    if (_receiveServer != null) return;

    try {
      _receiveServer = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      debugPrint('Transfer receive server started on port $port');

      _receiveServer!.listen((Socket client) async {
        await _handleIncomingTransfer(client);
      });
    } catch (e) {
      debugPrint('Error starting receive server: $e');
    }
  }

  Future<void> stopReceiveServer() async {
    await _receiveServer?.close();
    _receiveServer = null;
  }

  Future<void> _handleIncomingTransfer(Socket client) async {
    final transferId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Read metadata length
      final lengthBytes = await _readExactBytes(client, 4);
      final metadataLength = _bytesToInt(lengthBytes);

      // Read metadata
      final metadataBytes = await _readExactBytes(client, metadataLength);
      final metadataJson = utf8.decode(metadataBytes);
      final metadata = jsonDecode(metadataJson);

      if (metadata['type'] != 'file_transfer') {
        client.write(jsonEncode({'status': 'rejected', 'message': 'Invalid transfer type'}));
        await client.close();
        return;
      }

      final files = metadata['files'] as List;
      final totalBytes = metadata['total_size'] as int;

      // Accept transfer
      client.write(jsonEncode({'status': 'accepted', 'message': 'Ready to receive'}));
      await client.flush();

      int receivedBytes = 0;
      final startTime = DateTime.now();

      // Create progress tracking
      final progress = TransferProgress(
        fileId: transferId,
        fileName: 'Receiving files...',
        totalBytes: totalBytes,
        transferredBytes: 0,
        speed: 0,
        status: TransferStatus.transferring,
      );

      _activeTransfers[transferId] = progress;
      notifyListeners();

      // Receive files
      for (int fileIndex = 0; fileIndex < files.length; fileIndex++) {
        final fileInfo = files[fileIndex];
        final fileName = fileInfo['name'] as String;
        final fileSize = fileInfo['size'] as int;

        // Create unique filename if exists
        final filePath = await _getUniqueFilePath(fileName);
        final file = File(filePath);
        final fileSink = file.openWrite();

        int fileReceivedBytes = 0;

        // Receive file data
        await for (final chunk in client) {
          // Check for completion signal
          final chunkString = utf8.decode(chunk, allowMalformed: true);
          if (chunkString.trim() == 'TRANSFER_COMPLETE') {
            break;
          }

          fileSink.add(chunk);
          fileReceivedBytes += chunk.length;
          receivedBytes += chunk.length;

          if (fileReceivedBytes >= fileSize) {
            await fileSink.close();
            break;
          }

          final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000;
          final speed = elapsed > 0 ? (receivedBytes / elapsed).toDouble() : 0.0;

          final updatedProgress = TransferProgress(
            fileId: transferId,
            fileName: fileName,
            totalBytes: totalBytes,
            transferredBytes: receivedBytes,
            speed: speed,
            status: TransferStatus.transferring,
          );

          _activeTransfers[transferId] = updatedProgress;
          notifyListeners();
        }
      }

      final finalProgress = TransferProgress(
        fileId: transferId,
        fileName: 'Files received',
        totalBytes: totalBytes,
        transferredBytes: totalBytes,
        speed: 0,
        status: TransferStatus.completed,
      );

      _activeTransfers[transferId] = finalProgress;
      notifyListeners();

    } catch (e) {
      debugPrint('Error handling incoming transfer: $e');
      final errorProgress = TransferProgress(
        fileId: transferId,
        fileName: 'Receive failed',
        totalBytes: 0,
        transferredBytes: 0,
        speed: 0,
        status: TransferStatus.failed,
        error: e.toString(),
      );

      _activeTransfers[transferId] = errorProgress;
      notifyListeners();
    } finally {
      await client.close();
    }
  }

  Future<String> _getUniqueFilePath(String fileName) async {
    if (_downloadDirectory == null) {
      throw Exception('Download directory not initialized');
    }

    String filePath = path.join(_downloadDirectory!, fileName);
    int counter = 1;

    while (await File(filePath).exists()) {
      final nameWithoutExtension = path.basenameWithoutExtension(fileName);
      final extension = path.extension(fileName);
      final newFileName = '${nameWithoutExtension}_$counter$extension';
      filePath = path.join(_downloadDirectory!, newFileName);
      counter++;
    }

    return filePath;
  }

  Future<Uint8List> _readExactBytes(Socket socket, int count) async {
    final bytes = <int>[];
    await for (final chunk in socket) {
      bytes.addAll(chunk);
      if (bytes.length >= count) {
        return Uint8List.fromList(bytes.take(count).toList());
      }
    }
    throw Exception('Connection closed unexpectedly');
  }

  Uint8List _intToBytes(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  int _bytesToInt(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  Future<String> _calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void cancelTransfer(String transferId) {
    // Close active socket if exists
    final socket = _activeSockets[transferId];
    socket?.destroy();
    _activeSockets.remove(transferId);

    if (_activeTransfers.containsKey(transferId)) {
      _activeTransfers[transferId] = TransferProgress(
        fileId: transferId,
        fileName: _activeTransfers[transferId]!.fileName,
        totalBytes: _activeTransfers[transferId]!.totalBytes,
        transferredBytes: _activeTransfers[transferId]!.transferredBytes,
        speed: 0,
        status: TransferStatus.cancelled,
      );
      notifyListeners();
    }
  }

  void clearCompletedTransfers() {
    _activeTransfers.removeWhere((id, transfer) =>
    transfer.status == TransferStatus.completed ||
        transfer.status == TransferStatus.failed ||
        transfer.status == TransferStatus.cancelled);
    notifyListeners();
  }

  @override
  void dispose() {
    stopReceiveServer();
    // Close all active sockets
    for (final socket in _activeSockets.values) {
      socket.destroy();
    }
    _activeSockets.clear();
    super.dispose();
  }
}
