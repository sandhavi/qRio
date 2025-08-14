import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class BluetoothChatService {
  static final BluetoothChatService _instance =
      BluetoothChatService._internal();
  factory BluetoothChatService() => _instance;
  BluetoothChatService._internal();

  // NOTE: Previous implementation used classic SPP UUID (00001101-...).
  // flutter_blue_plus is BLE only, so we instead perform a generic
  // scan & discover and pick the first characteristic that supports
  // write + notify. If you control BOTH devices you should expose a
  // custom service/characteristic. Placeholder UUIDs kept only for
  // potential future filtering.
  static const String serviceUuidHint =
      "12345678-1234-5678-1234-56789ABCDEF0"; // replace when you add a true custom service
  static const String characteristicUuidHint =
      "12345678-1234-5678-1234-56789ABCDEF1"; // replace accordingly

  fbp.BluetoothDevice? connectedDevice;
  fbp.BluetoothCharacteristic? messageCharacteristic;
  StreamController<Map<String, dynamic>> messageStreamController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get messageStream =>
      messageStreamController.stream;

  bool isHost = false;
  bool isConnected = false;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _connectionSubscription;
  static const MethodChannel _peripheralChannel = MethodChannel(
    'qrio/ble_peripheral',
  );

  Future<bool> checkAndRequestPermissions() async {
    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    return statuses.values.every(
      (status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );
  }

  Future<bool> initializeBluetooth() async {
    try {
      bool permissionsGranted = await checkAndRequestPermissions();
      if (!permissionsGranted) {
        debugPrint('Bluetooth permissions not granted');
        return false;
      }

      // Check if Bluetooth is available and on
      if (await fbp.FlutterBluePlus.isSupported == false) {
        debugPrint("Bluetooth not supported by this device");
        return false;
      }

      // Turn on Bluetooth if it's off
      var state = await fbp.FlutterBluePlus.adapterState.first;
      if (state != fbp.BluetoothAdapterState.on) {
        debugPrint('Bluetooth is not on');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      return false;
    }
  }

  Future<void> startAdvertising(String sessionId) async {
    try {
      isHost = true;
      try {
        final started = await _peripheralChannel.invokeMethod<bool>(
          'startPeripheral',
          {'sessionId': sessionId},
        );
        debugPrint('Peripheral start result: $started');
      } catch (e) {
        debugPrint('Peripheral start failed (fallback to passive host): $e');
      }
    } catch (e) {
      debugPrint('Error starting advertising: $e');
    }
  }

  Future<List<fbp.ScanResult>> scanForDevices({
    Duration duration = const Duration(seconds: 6),
  }) async {
    final completer = Completer<List<fbp.ScanResult>>();
    final Map<String, fbp.ScanResult> found = {};
    try {
      await fbp.FlutterBluePlus.startScan(timeout: duration);
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen(
        (results) {
          for (var r in results) {
            if (r.device.platformName.isNotEmpty) {
              found[r.device.remoteId.str] = r;
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () async {
          if (!completer.isCompleted) completer.complete(found.values.toList());
        },
      );
      // Wait scan duration then stop if not already completed
      await Future.delayed(duration);
      await fbp.FlutterBluePlus.stopScan();
      if (!completer.isCompleted) completer.complete(found.values.toList());
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
      if (!completer.isCompleted) completer.complete(found.values.toList());
    }
    return completer.future;
  }

  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      debugPrint(
        'Connecting to ${device.platformName} (${device.remoteId.str})',
      );
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );
      connectedDevice = device;

      // Discover services & characteristics
      List<fbp.BluetoothService> services = await device.discoverServices();
      fbp.BluetoothCharacteristic? foundCharacteristic;
      for (var s in services) {
        for (var c in s.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          // Skip GAP/GATT service characteristics (generic, read-only or restricted)
          if (uuid.contains('2a05') || uuid.contains('2a00')) continue;
          if ((c.properties.write || c.properties.writeWithoutResponse) &&
              c.properties.notify) {
            foundCharacteristic = c;
            break;
          }
        }
        if (foundCharacteristic != null) break;
      }
      if (foundCharacteristic == null) {
        debugPrint('No suitable write+notify characteristic found');
        await device.disconnect();
        connectedDevice = null;
        return false;
      }
      messageCharacteristic = foundCharacteristic;
      try {
        if (foundCharacteristic.properties.notify) {
          await foundCharacteristic.setNotifyValue(true);
        }
      } catch (e) {
        debugPrint('Notify enable failed (continuing): $e');
      }
      foundCharacteristic.lastValueStream.listen(
        (value) => _handleReceivedMessage(value),
      );
      isConnected = true;

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected');
          isConnected = false;
          connectedDevice = null;
          messageCharacteristic = null;
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      return false;
    }
  }

  Future<void> sendMessage(String message, String senderId) async {
    if (messageCharacteristic == null || !isConnected) {
      debugPrint('Not connected to send message');
      return;
    }

    try {
      Map<String, dynamic> messageData = {
        'text': message,
        'senderId': senderId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      String jsonMessage = jsonEncode(messageData);
      List<int> bytes = utf8.encode(jsonMessage);

      // Split message if it's too long (BLE has packet size limits)
      // Typical BLE MTU is 20 bytes by default; flutter_blue_plus negotiates higher on some devices.
      // Conservative chunk size to improve reliability.
      const int chunkSize = 180;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await messageCharacteristic!.write(
          bytes.sublist(i, end),
          withoutResponse: false,
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _handleReceivedMessage(List<int> value) {
    try {
      String jsonMessage = utf8.decode(value);
      Map<String, dynamic> messageData = jsonDecode(jsonMessage);
      messageStreamController.add(messageData);
    } catch (e) {
      debugPrint('Error handling received message: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (isHost) {
        try {
          await _peripheralChannel.invokeMethod('stopPeripheral');
        } catch (_) {}
      }
      await _scanSubscription?.cancel();
      await _stateSubscription?.cancel();
      await _connectionSubscription?.cancel();

      if (connectedDevice != null) {
        await connectedDevice!.disconnect();
      }

      connectedDevice = null;
      messageCharacteristic = null;
      isConnected = false;
      isHost = false;
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  void dispose() {
    disconnect();
    messageStreamController.close();
  }
}
