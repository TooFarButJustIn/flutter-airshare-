import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';

class NetworkService with ChangeNotifier {
  static const int DISCOVERY_PORT = 8888;
  static const int TRANSFER_PORT = 8889;

  final _uuid = const Uuid();
  late String _deviceId;
  late String _deviceName;

  RawDatagramSocket? _discoverySocket;
  ServerSocket? _transferServer;
  Timer? _discoveryTimer;
  Timer? _heartbeatTimer;

  bool _isDiscoverable = false;
  bool _isDiscovering = false;
  final Map<String, Device> _discoveredDevices = {};

  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  bool get isDiscoverable => _isDiscoverable;
  bool get isDiscovering => _isDiscovering;
  List<Device> get discoveredDevices => _discoveredDevices.values.toList();

  NetworkService() {
    _deviceId = _uuid.v4();
    _deviceName = _getDeviceName();
  }

  String _getDeviceName() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isMacOS) return 'MacBook';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux Device';
    return 'Unknown Device';
  }

  DeviceType _getDeviceType() {
    if (Platform.isAndroid) return DeviceType.android;
    if (Platform.isIOS) return DeviceType.iOS;
    if (Platform.isMacOS) return DeviceType.mac;
    if (Platform.isWindows) return DeviceType.windows;
    if (Platform.isLinux) return DeviceType.linux;
    return DeviceType.unknown;
  }

  Future<void> startDiscoverable() async {
    if (_isDiscoverable) return;

    try {
      // Start UDP discovery server
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, DISCOVERY_PORT);
      _discoverySocket!.listen(_handleDiscoveryMessage);

      // Start TCP transfer server
      _transferServer = await ServerSocket.bind(InternetAddress.anyIPv4, TRANSFER_PORT);

      // Start heartbeat broadcasts
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) => _broadcastPresence());

      _isDiscoverable = true;
      notifyListeners();
      debugPrint('Started discoverable mode on port $DISCOVERY_PORT');
    } catch (e) {
      debugPrint('Error starting discoverable mode: $e');
    }
  }

  Future<void> stopDiscoverable() async {
    _discoverySocket?.close();
    _transferServer?.close();
    _heartbeatTimer?.cancel();
    _isDiscoverable = false;
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    notifyListeners();

    _discoveryTimer = Timer.periodic(const Duration(seconds: 2), (_) => _scanForDevices());

    // Clean up old devices
    Timer.periodic(const Duration(seconds: 10), (_) => _cleanupOldDevices());
  }

  Future<void> stopDiscovery() async {
    _discoveryTimer?.cancel();
    _isDiscovering = false;
    _discoveredDevices.clear();
    notifyListeners();
  }

  void _handleDiscoveryMessage(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _discoverySocket!.receive();
      if (datagram != null) {
        try {
          final message = utf8.decode(datagram.data);
          final data = jsonDecode(message);

          if (data['type'] == 'presence' && data['id'] != _deviceId) {
            final device = Device.fromJson(data, datagram.address);
            _discoveredDevices[device.id] = device;
            notifyListeners();

            // Send response if it's a discovery request
            if (data['response_requested'] == true) {
              _sendPresenceResponse(datagram.address);
            }
          }
        } catch (e) {
          debugPrint('Error parsing discovery message: $e');
        }
      }
    }
  }

  Future<void> _scanForDevices() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP == null) return;

      // Broadcast discovery request
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final message = jsonEncode({
        'type': 'presence',
        'id': _deviceId,
        'name': _deviceName,
        'device_type': _getDeviceType().index,
        'port': TRANSFER_PORT,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'response_requested': true,
      });

      socket.send(utf8.encode(message), InternetAddress('255.255.255.255'), DISCOVERY_PORT);
      socket.close();
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
    }
  }

  void _broadcastPresence() {
    if (!_isDiscoverable) return;

    final message = jsonEncode({
      'type': 'presence',
      'id': _deviceId,
      'name': _deviceName,
      'device_type': _getDeviceType().index,
      'port': TRANSFER_PORT,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'response_requested': false,
    });

    _discoverySocket?.send(utf8.encode(message), InternetAddress('255.255.255.255'), DISCOVERY_PORT);
  }

  void _sendPresenceResponse(InternetAddress address) {
    if (!_isDiscoverable) return;

    final message = jsonEncode({
      'type': 'presence',
      'id': _deviceId,
      'name': _deviceName,
      'device_type': _getDeviceType().index,
      'port': TRANSFER_PORT,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'response_requested': false,
    });

    _discoverySocket?.send(utf8.encode(message), address, DISCOVERY_PORT);
  }

  void _cleanupOldDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((id, device) =>
    now.difference(device.lastSeen).inSeconds > 15);
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscoverable();
    stopDiscovery();
    super.dispose();
  }
}
