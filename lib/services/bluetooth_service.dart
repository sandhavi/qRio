import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // Custom service UUID for QRio app
  static const String SERVICE_UUID = "00001101-0000-1000-8000-00805F9B34FB";
  static const String CHARACTERISTIC_UUID = "00002A00-0000-1000-8000-00805F9B34FB";

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? messageCharacteristic;
  StreamController<Map<String, dynamic>> messageStreamController = StreamController.broadcast();
  
  Stream<Map<String, dynamic>> get messageStream => messageStreamController.stream;
  
  bool isHost = false;
  bool isConnected = false;
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _connectionSubscription;

  Future<bool> checkAndRequestPermissions() async {
    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    return statuses.values.every((status) => 
      status == PermissionStatus.granted || 
      status == PermissionStatus.limited
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
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint("Bluetooth not supported by this device");
        return false;
      }

      // Turn on Bluetooth if it's off
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
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
      // On Android, we'll use device name to advertise session ID
      // Note: iOS doesn't support custom advertising data easily
      await FlutterBluePlus.setName('QRio_$sessionId');
      debugPrint('Started advertising as QRio_$sessionId');
    } catch (e) {
      debugPrint('Error starting advertising: $e');
    }
  }

  Future<List<BluetoothDevice>> scanForDevices(String sessionId) async {
    List<BluetoothDevice> qrioDevices = [];
    
    try {
      // Start scanning
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          String deviceName = result.device.platformName;
          if (deviceName.startsWith('QRio_$sessionId')) {
            if (!qrioDevices.contains(result.device)) {
              qrioDevices.add(result.device);
            }
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
    }
    
    return qrioDevices;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;
      isConnected = true;
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our custom service and characteristic
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == SERVICE_UUID) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.properties.write && characteristic.properties.notify) {
              messageCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                _handleReceivedMessage(value);
              });
              
              break;
            }
          }
        }
      }
      
      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
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
      const int chunkSize = 512;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await messageCharacteristic!.write(bytes.sublist(i, end), withoutResponse: false);
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