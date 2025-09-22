import 'dart:io';

enum DeviceType { android, iOS, windows, mac, linux, unknown }

class Device {
  final String id;
  final String name;
  final DeviceType type;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;
  final String? model;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.model,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'address': address.address,
      'port': port,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'model': model,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json, InternetAddress address) {
    return Device(
      id: json['id'],
      name: json['name'],
      type: DeviceType.values[json['type']],
      address: address,
      port: json['port'],
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen']),
      model: json['model'],
    );
  }
}

class FileItem {
  final String name;
  final String path;
  final int size;
  final String mimeType;
  final DateTime lastModified;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.lastModified,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class TransferProgress {
  final String fileId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final double speed; // bytes per second
  final TransferStatus status;
  final String? error;

  TransferProgress({
    required this.fileId,
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.speed,
    required this.status,
    this.error,
  });

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  String get speedFormatted {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Duration get estimatedTimeRemaining {
    if (speed <= 0) return Duration.zero;
    final remainingBytes = totalBytes - transferredBytes;
    return Duration(seconds: (remainingBytes / speed).round());
  }
}

enum TransferStatus { pending, connecting, transferring, completed, failed, cancelled }
