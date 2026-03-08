import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/device.dart';

class NetworkDiscoveryService {
  static const int discoveryPort = 45679;
  RawDatagramSocket? _socket;
  final StreamController<Device> _deviceFoundController = StreamController.broadcast();

  Stream<Device> get onDeviceFound => _deviceFoundController.stream;

  Future<void> startListening(Device localDevice) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _socket?.broadcastEnabled = true;
      
      // Enable multicast for better compatibility (IP_MULTICAST_LOOP = 11)
      try {
        _socket?.setRawOption(RawSocketOption(
          RawSocketOption.levelIPv4,
          11, // IP_MULTICAST_LOOP
          Uint8List.fromList([1]),
        ));
      } catch (e) {
        // Ignore if multicast option is not supported on this platform
      }

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            try {
              final message = utf8.decode(datagram.data);

              if (message == 'WHO_IS_APEX_FILE') {
                _respondToDiscovery(localDevice, datagram.address);
              } else if (message.startsWith('I_AM_APEX_FILE:')) {
                final deviceData = jsonDecode(message.substring(15));
                if (deviceData['id'] != localDevice.id) {
                  final device = Device(
                    id: deviceData['id'],
                    name: deviceData['name'],
                    ip: deviceData['ip'],
                    type: deviceData['type'],
                    port: deviceData['port'],
                  );
                  _deviceFoundController.add(device);
                }
              }
            } catch (e) {
              // Ignore invalid or malformed packets
            }
          }
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> searchForDevices() async {
    if (_socket == null) {
      return;
    }
    
    try {
      final data = utf8.encode('WHO_IS_APEX_FILE');
      // Send multiple times for reliability
      for (int i = 0; i < 3; i++) {
        _socket?.send(data, InternetAddress('255.255.255.255'), discoveryPort);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      // Ignore broadcast errors - network may be unavailable
    }
  }

  void _respondToDiscovery(Device localDevice, InternetAddress senderAddress) {
    try {
      final response = 'I_AM_APEX_FILE:${jsonEncode({
        'id': localDevice.id,
        'name': localDevice.name,
        'ip': localDevice.ip,
        'type': localDevice.type,
        'port': localDevice.port,
      })}';
      final data = utf8.encode(response);
      // Send response multiple times for reliability
      for (int i = 0; i < 2; i++) {
        _socket?.send(data, senderAddress, discoveryPort);
      }
    } catch (e) {
      // Ignore response send errors
    }
  }

  void dispose() {
    _socket?.close();
    _deviceFoundController.close();
  }
}
