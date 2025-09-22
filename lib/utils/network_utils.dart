import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static Future<String?> getLocalIP() async {
    try {
      return await NetworkInfo().getWifiIP();
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getWifiName() async {
    try {
      return await NetworkInfo().getWifiName();
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isConnectedToWifi() async {
    try {
      final wifiName = await getWifiName();
      return wifiName != null && wifiName != '<unknown ssid>';
    } catch (e) {
      return false;
    }
  }

  static Future<List<InternetAddress>> getNetworkInterfaces() async {
    final interfaces = <InternetAddress>[];
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            interfaces.add(addr);
          }
        }
      }
    } catch (e) {
      // Handle error
    }
    return interfaces;
  }
}
