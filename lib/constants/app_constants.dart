class AppConstants {
  static const String appName = 'AirShare';
  static const String appVersion = '1.0.0';

  // Network
  static const int discoveryPort = 8888;
  static const int transferPort = 8889;
  static const int maxRetries = 3;
  static const int timeoutSeconds = 30;

  // File Transfer
  static const int chunkSize = 64 * 1024; // 64KB
  static const int maxFileSize = 1024 * 1024 * 1024; // 1GB

  static const List<String> supportedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'
  ];

  static const List<String> supportedVideoTypes = [
    'mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'
  ];

  // UI
  static const double borderRadius = 16.0;
  static const double cardElevation = 4.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}
