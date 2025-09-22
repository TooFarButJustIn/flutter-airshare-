import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import '../models/device_model.dart';

class FileService with ChangeNotifier {
  List<FileItem> _selectedFiles = [];
  String? _downloadDirectory;

  List<FileItem> get selectedFiles => _selectedFiles;
  String? get downloadDirectory => _downloadDirectory;

  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    _downloadDirectory = '${directory.path}/AirShare';
    await Directory(_downloadDirectory!).create(recursive: true);
  }

  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withReadStream: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        _selectedFiles.clear();
        for (final file in result.files) {
          if (file.path != null) {
            final fileStats = await File(file.path!).stat();
            final mimeType = lookupMimeType(file.path!) ?? 'application/octet-stream';

            _selectedFiles.add(FileItem(
              name: file.name,
              path: file.path!,
              size: file.size,
              mimeType: mimeType,
              lastModified: fileStats.modified,
            ));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  Future<void> pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        await _processPickedFiles(result.files);
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> pickVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.video,
      );

      if (result != null && result.files.isNotEmpty) {
        await _processPickedFiles(result.files);
      }
    } catch (e) {
      debugPrint('Error picking videos: $e');
    }
  }

  Future<void> _processPickedFiles(List<PlatformFile> files) async {
    for (final file in files) {
      if (file.path != null) {
        final fileStats = await File(file.path!).stat();
        final mimeType = lookupMimeType(file.path!) ?? 'application/octet-stream';

        _selectedFiles.add(FileItem(
          name: file.name,
          path: file.path!,
          size: file.size,
          mimeType: mimeType,
          lastModified: fileStats.modified,
        ));
      }
    }
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      notifyListeners();
    }
  }

  void clearFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }

  String get totalSizeFormatted {
    int totalBytes = _selectedFiles.fold(0, (sum, file) => sum + file.size);
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
