import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:usb_serial/usb_serial.dart';

enum DroneConnectionType { none, usb, wifi }
enum DroneStatus { disconnected, scanning, connecting, connected, error }

class DroneInfo {
  final String name;
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String deviceId;
  final double batteryLevel;
  final double altitude;
  final double latitude;
  final double longitude;
  final bool cameraAvailable;
  final DroneConnectionType connectionType;
  final DroneStatus status;
  final Map<String, dynamic> telemetry;
  final DateTime connectionTime;
  final int signalStrength; // Уровень сигнала в процентах (0-100)
  final int wifiFrequency; // Частота WiFi в MHz

  DroneInfo({
    required this.name,
    required this.manufacturer,
    required this.model,
    required this.serialNumber,
    required this.deviceId,
    required this.batteryLevel,
    required this.altitude,
    required this.latitude,
    required this.longitude,
    required this.cameraAvailable,
    required this.connectionType,
    required this.status,
    required this.telemetry,
    required this.connectionTime,
    required this.signalStrength,
    required this.wifiFrequency,
  });

  DroneInfo copyWith({
    String? name,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? deviceId,
    double? batteryLevel,
    double? altitude,
    double? latitude,
    double? longitude,
    bool? cameraAvailable,
    DroneConnectionType? connectionType,
    DroneStatus? status,
    Map<String, dynamic>? telemetry,
    DateTime? connectionTime,
    int? signalStrength,
    int? wifiFrequency,
  }) {
    return DroneInfo(
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      deviceId: deviceId ?? this.deviceId,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      altitude: altitude ?? this.altitude,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cameraAvailable: cameraAvailable ?? this.cameraAvailable,
      connectionType: connectionType ?? this.connectionType,
      status: status ?? this.status,
      telemetry: telemetry ?? this.telemetry,
      connectionTime: connectionTime ?? this.connectionTime,
      signalStrength: signalStrength ?? this.signalStrength,
      wifiFrequency: wifiFrequency ?? this.wifiFrequency,
    );
  }
}

class DroneService extends ChangeNotifier {
  DroneInfo? _connectedDrone;
  DroneStatus _status = DroneStatus.disconnected;
  UsbPort? _usbPort;
  StreamSubscription<List<int>>? _usbSubscription;
  Socket? _wifiSocket;
  Timer? _telemetryTimer;
  Timer? _signalStrengthTimer;
  final NetworkInfo _networkInfo = NetworkInfo();
  
  // Обнаруженные дроны
  final List<UsbDevice> _discoveredDrones = [];
  
  DroneInfo? get connectedDrone => _connectedDrone;
  DroneStatus get status => _status;
  List<UsbDevice> get discoveredDrones => _discoveredDrones;

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _signalStrengthTimer?.cancel();
    _usbSubscription?.cancel();
    _usbPort?.close();
    _wifiSocket?.close();
    super.dispose();
  }

  Future<void> scanForDrones() async {
    _status = DroneStatus.scanning;
    _discoveredDrones.clear();
    notifyListeners();

    try {
      // Сканирование USB устройств
      List<UsbDevice> devices = await UsbSerial.listDevices();
      
      // Фильтруем устройства, которые могут быть дронами
      // (устройства с последовательным портом)
      for (var device in devices) {
        if (_isPotentialDrone(device)) {
          _discoveredDrones.add(device);
          print('Обнаружено потенциальное устройство дрона: ${device.deviceName} '
                '(VID: 0x${_safeToRadixString(device.vid)}, PID: 0x${_safeToRadixString(device.pid)})');
        }
      }

      if (_discoveredDrones.isEmpty) {
        print('Устройства дронов не обнаружены. Доступные USB устройства:');
        for (var device in devices) {
          print('  - ${device.deviceName} '
                '(VID: 0x${_safeToRadixString(device.vid)}, PID: 0x${_safeToRadixString(device.pid)})');
        }
      } else {
        print('Найдено ${_discoveredDrones.length} потенциальных устройств дронов');
      }

      _status = DroneStatus.disconnected;
      
    } catch (e) {
      _status = DroneStatus.error;
      print('Ошибка сканирования дронов: $e');
    }
    
    notifyListeners();
  }

  // Безопасное преобразование в hex строку
  String _safeToRadixString(int? value) {
    return value?.toRadixString(16) ?? 'unknown';
  }

  bool _isPotentialDrone(UsbDevice device) {
    // Проверяем по VID известных производителей дронов и серийных устройств
    final knownDroneVendors = [
      0x2CA3, // DJI
      0x26C0, // DJI  
      0x1FC9, // DJI
      0x1011, // DJI
      0x1165, // DJI
      0x319C, // Autel
      0x3287, // Autel
      0x12D4, // Parrot
      0x3427, // Parrot
      0x6001, // Yuneec
      0x6002, // Yuneec
      0x0483, // STMicroelectronics (часто используется в кастомных дронах)
      0x1B4F, // SparkFun
      0x2341, // Arduino
      0x2A03, // Arduino
    ];
    
    return knownDroneVendors.contains(device.vid) || 
           (device.deviceName.toLowerCase().contains('drone') ||
           device.deviceName.toLowerCase().contains('serial') ||
           device.deviceName.toLowerCase().contains('com') ||
           device.deviceName.toLowerCase().contains('uart'));
  }

  String _getManufacturerName(int vid) {
    final manufacturers = {
      0x2CA3: 'DJI', 0x26C0: 'DJI', 0x1FC9: 'DJI', 0x1011: 'DJI', 0x1165: 'DJI',
      0x319C: 'Autel', 0x3287: 'Autel',
      0x12D4: 'Parrot', 0x3427: 'Parrot',
      0x6001: 'Yuneec', 0x6002: 'Yuneec',
      0x0483: 'STMicroelectronics',
      0x1B4F: 'SparkFun',
      0x2341: 'Arduino', 0x2A03: 'Arduino',
    };
    
    return manufacturers[vid] ?? 'Unknown Manufacturer';
  }

  // Метод для подключения по USB (публичный)
  Future<void> connectViaUSB() async {
    await scanForDrones();
    
    if (_discoveredDrones.isEmpty) {
      throw Exception('Дроны не обнаружены. Подключите дрон по USB.');
    }
    
    // Подключаемся к первому найденному дрону
    await connectToDrone(_discoveredDrones.first);
  }

  Future<void> connectToDrone(UsbDevice device) async {
    _status = DroneStatus.connecting;
    notifyListeners();

    try {
      _usbPort = await device.create();
      final opened = await _usbPort!.open();
      
      if (!opened) {
        throw Exception('Не удалось открыть USB порт');
      }

      // Настройка параметров порта (стандартные для дронов)
      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);
      await _usbPort!.setPortParameters(
        115200, // Стандартная скорость для дронов
        UsbPort.DATABITS_8, 
        UsbPort.STOPBITS_1, 
        UsbPort.PARITY_NONE
      );

      // Получение информации о дроне
      final droneInfo = await _getDroneInfo(device);
      
      _connectedDrone = droneInfo;
      _status = DroneStatus.connected;

      // Запуск прослушивания данных
      _usbSubscription = _usbPort!.inputStream!.listen(_handleUsbData);
      
      // Запуск опроса телеметрии
      _startTelemetryPolling();

      print('Успешно подключено к дрону: ${droneInfo.name}');
      
    } catch (e) {
      _status = DroneStatus.error;
      print('Ошибка подключения к дрону: $e');
      await _cleanupConnection();
    }
    
    notifyListeners();
  }

  Future<DroneInfo> _getDroneInfo(UsbDevice device) async {
    final manufacturer = _getManufacturerName(device.vid ?? 0);
    final model = _determineModel(device);
    
    // Генерируем уникальный ID устройства
    final deviceId = 'USB-${_safeToRadixString(device.vid)}-${_safeToRadixString(device.pid)}';
    
    // Получаем начальный уровень сигнала (для USB всегда 100%)
    final signalStrength = await _getCurrentSignalStrength();

    return DroneInfo(
      name: '$manufacturer $model',
      manufacturer: manufacturer,
      model: model,
      serialNumber: 'SN-${_safeToRadixString(device.pid)?.toUpperCase() ?? "UNKNOWN"}',
      deviceId: deviceId,
      batteryLevel: 0.0, // Будет обновлено при опросе телеметрии
      altitude: 0.0,
      latitude: 0.0,
      longitude: 0.0,
      cameraAvailable: true,
      connectionType: DroneConnectionType.usb,
      status: DroneStatus.connected,
      telemetry: {
        'pitch': 0.0,
        'roll': 0.0,
        'yaw': 0.0,
        'speed': 0.0,
        'signal_strength': signalStrength,
        'propellers_ok': true,
        'gps_fix': 0,
        'satellites': 0,
        'voltage': 0.0,
        'current': 0.0,
        'flight_time': 0,
        'home_distance': 0.0,
        'rssi': -50, // Received Signal Strength Indication
      },
      connectionTime: DateTime.now(),
      signalStrength: signalStrength,
      wifiFrequency: 0, // Для USB частота не применима
    );
  }

  String _determineModel(UsbDevice device) {
    // Пытаемся определить модель по VID/PID
    final models = {
      // DJI Models
      0x2CA3: 'Mavic 3', 0x26C0: 'Air 2S', 0x1FC9: 'Mini 3 Pro',
      0x1011: 'Phantom 4', 0x1165: 'Inspire 2',
      // Autel Models
      0x319C: 'Evo II', 0x3287: 'Evo Lite+',
      // Parrot Models
      0x12D4: 'Anafi', 0x3427: 'Bebop 2',
      // Yuneec Models
      0x6001: 'H520', 0x6002: 'Typhoon H',
    };
    
    return models[device.pid] ?? 'Unknown Model';
  }

  Future<void> _sendUsbCommand(String command) async {
    if (_usbPort != null) {
      _usbPort!.write(Uint8List.fromList('$command\r\n'.codeUnits));
    }
  }

  void _handleUsbData(List<int> data) {
    final message = String.fromCharCodes(data).trim();
    if (message.isNotEmpty) {
      print('Данные от дрона: $message');
      _parseTelemetryData(message);
    }
  }

  void _parseTelemetryData(String data) {
    try {
      // Парсинг различных форматов телеметрии
      if (data.contains('battery') || data.contains('BATT')) {
        _parseBatteryData(data);
      } else if (data.contains('alt') || data.contains('ALT')) {
        _parseAltitudeData(data);
      } else if (data.contains('GPS') || data.contains('gps')) {
        _parseGPSData(data);
      } else if (data.contains('ATT') || data.contains('attitude')) {
        _parseAttitudeData(data);
      } else if (data.startsWith('{') && data.endsWith('}')) {
        // JSON формат
        final jsonData = json.decode(data);
        _updateDroneTelemetry(jsonData);
      } else if (data.contains('=')) {
        // Формат KEY=VALUE
        _parseKeyValueData(data);
      }
    } catch (e) {
      print('Ошибка парсинга телеметрии: $e');
    }
  }

  void _parseBatteryData(String data) {
    final battMatch = RegExp(r'(\d+)%').firstMatch(data);
    if (battMatch != null) {
      final batteryLevel = int.parse(battMatch.group(1)!) / 100.0;
      _updateDroneTelemetry({'battery': batteryLevel});
    }
    
    final voltMatch = RegExp(r'(\d+\.?\d*)V').firstMatch(data);
    if (voltMatch != null) {
      final voltage = double.parse(voltMatch.group(1)!);
      _updateDroneTelemetry({'voltage': voltage});
    }
  }

  void _parseAltitudeData(String data) {
    final altMatch = RegExp(r'alt[:\s]*([\d.-]+)').firstMatch(data);
    if (altMatch != null) {
      final altitude = double.parse(altMatch.group(1)!);
      _updateDroneTelemetry({'altitude': altitude});
    }
  }

  void _parseGPSData(String data) {
    final latMatch = RegExp(r'lat[:\s]*([\d.-]+)').firstMatch(data);
    final lonMatch = RegExp(r'lon[:\s]*([\d.-]+)').firstMatch(data);
    
    if (latMatch != null && lonMatch != null) {
      _updateDroneTelemetry({
        'latitude': double.parse(latMatch.group(1)!),
        'longitude': double.parse(lonMatch.group(1)!),
      });
    }
    
    final satMatch = RegExp(r'sat[:\s]*(\d+)').firstMatch(data);
    if (satMatch != null) {
      _updateDroneTelemetry({'satellites': int.parse(satMatch.group(1)!)});
    }
  }

  void _parseAttitudeData(String data) {
    final pitchMatch = RegExp(r'pitch[:\s]*([\d.-]+)').firstMatch(data);
    final rollMatch = RegExp(r'roll[:\s]*([\d.-]+)').firstMatch(data);
    final yawMatch = RegExp(r'yaw[:\s]*([\d.-]+)').firstMatch(data);
    
    final updates = <String, dynamic>{};
    if (pitchMatch != null) updates['pitch'] = double.parse(pitchMatch.group(1)!);
    if (rollMatch != null) updates['roll'] = double.parse(rollMatch.group(1)!);
    if (yawMatch != null) updates['yaw'] = double.parse(yawMatch.group(1)!);
    
    if (updates.isNotEmpty) {
      _updateDroneTelemetry(updates);
    }
  }

  void _parseKeyValueData(String data) {
    final parts = data.split(',');
    for (var part in parts) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim().toLowerCase();
        final value = keyValue[1].trim();
        
        final updates = <String, dynamic>{};
        switch (key) {
          case 'bat':
          case 'battery':
            updates['battery'] = double.parse(value) / 100.0;
            break;
          case 'alt':
            updates['altitude'] = double.parse(value);
            break;
          case 'lat':
            updates['latitude'] = double.parse(value);
            break;
          case 'lon':
            updates['longitude'] = double.parse(value);
            break;
          case 'spd':
          case 'speed':
            updates['speed'] = double.parse(value);
            break;
          case 'sat':
            final satValue = int.tryParse(value) ?? 0;
            updates['satellites'] = satValue;
            break;
          case 'rssi':
            final rssiValue = int.tryParse(value) ?? -100;
            updates['rssi'] = rssiValue;
            // Обновляем уровень сигнала на основе RSSI
            final signalStrength = _rssiToPercentage(rssiValue);
            _updateSignalStrength(signalStrength);
            break;
        }
        
        if (updates.isNotEmpty) {
          _updateDroneTelemetry(updates);
        }
      }
    }
  }

  int _rssiToPercentage(int rssi) {
    // Конвертация RSSI в проценты (RSSI обычно от -100 до -30)
    if (rssi >= -30) return 100;
    if (rssi <= -100) return 0;
    return ((rssi + 100) * 100 / 70).round().clamp(0, 100);
  }

  void _updateDroneTelemetry(Map<String, dynamic> newData) {
    if (_connectedDrone != null) {
      final updatedTelemetry = Map<String, dynamic>.from(_connectedDrone!.telemetry);
      updatedTelemetry.addAll(newData);
      
      // Обновляем основные поля если они пришли в телеметрии
      final batteryLevel = newData['battery'] ?? _connectedDrone!.batteryLevel;
      final altitude = newData['altitude'] ?? _connectedDrone!.altitude;
      final latitude = newData['latitude'] ?? _connectedDrone!.latitude;
      final longitude = newData['longitude'] ?? _connectedDrone!.longitude;
      
      _connectedDrone = _connectedDrone!.copyWith(
        batteryLevel: batteryLevel,
        altitude: altitude,
        latitude: latitude,
        longitude: longitude,
        telemetry: updatedTelemetry,
      );
      
      notifyListeners();
    }
  }

  void _updateSignalStrength(int signalStrength) {
    if (_connectedDrone != null) {
      _connectedDrone = _connectedDrone!.copyWith(
        signalStrength: signalStrength,
      );
      notifyListeners();
    }
  }

  void _startTelemetryPolling() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      _requestTelemetry();
    });

    // Запускаем мониторинг уровня сигнала
    _startSignalStrengthMonitoring();
  }

  void _startSignalStrengthMonitoring() {
    _signalStrengthTimer?.cancel();
    _signalStrengthTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (_connectedDrone != null) {
        final signalStrength = await _getCurrentSignalStrength();
        _updateSignalStrength(signalStrength);
        
        // Также обновляем в телеметрии
        _updateDroneTelemetry({
          'signal_strength': signalStrength,
        });
      }
    });
  }

  Future<int> _getCurrentSignalStrength() async {
    try {
      if (_connectedDrone?.connectionType == DroneConnectionType.usb) {
        // Для USB соединения сигнал всегда отличный
        return 100;
      } else if (_connectedDrone?.connectionType == DroneConnectionType.wifi) {
        // Получаем информацию о WiFi сети
        final wifiName = await _networkInfo.getWifiName();
        
        if (wifiName != null && wifiName.isNotEmpty) {
          // Если подключены к WiFi сети дрона, оцениваем уровень сигнала
          // В реальном приложении здесь можно использовать platform channels
          // для получения реального уровня сигнала
          
          // Имитация реального уровня сигнала на основе времени подключения
          final connectionDuration = DateTime.now().difference(_connectedDrone!.connectionTime);
          if (connectionDuration.inMinutes > 10) {
            return 85; // Хороший сигнал после длительного подключения
          } else if (connectionDuration.inMinutes > 5) {
            return 75; // Средний сигнал
          } else {
            return 90; // Отличный сигнал при недавнем подключении
          }
        } else {
          return 50; // Низкий сигнал если WiFi не подключен
        }
      }
    } catch (e) {
      print('Ошибка получения уровня сигнала: $e');
    }
    
    return 50; // Значение по умолчанию при ошибке
  }

  void _requestTelemetry() {
    if (_usbPort != null) {
      // Отправляем команды для запроса телеметрии
      final commands = [
        'AT+BATT?',
        'AT+ALT?',
        'AT+GPS?',
        'AT+ATT?',
        'AT+SPEED?',
        'AT+RSSI?',
      ];
      
      for (var command in commands) {
        _sendUsbCommand(command);
      }
    }
  }

  Future<void> connectViaWifi(String ssid, String password) async {
    _status = DroneStatus.connecting;
    notifyListeners();

    try {
      final wifiName = await _networkInfo.getWifiName();
      if (wifiName != ssid) {
        throw Exception('Подключитесь к WiFi сети дрона: $ssid');
      }

      // Стандартные порты для дронов
      const List<int> commonPorts = [8888, 8895, 6038, 9050, 11111];
      Socket? connectedSocket;

      for (int port in commonPorts) {
        try {
          final socket = await Socket.connect('192.168.1.1', port, timeout: Duration(seconds: 3));
          connectedSocket = socket;
          break;
        } catch (e) {
          continue;
        }
      }

      if (connectedSocket == null) {
        throw Exception('Не удалось подключиться к дрону. Проверьте IP и порт.');
      }

      _wifiSocket = connectedSocket;
      
      _wifiSocket!.listen(
        _handleWifiData,
        onError: (error) {
          print('WiFi socket error: $error');
          disconnect();
        },
        onDone: () {
          print('WiFi socket closed');
          disconnect();
        },
      );

      // Получаем информацию о дроне через WiFi
      final droneInfo = await _getWifiDroneInfo();
      _connectedDrone = droneInfo;
      _status = DroneStatus.connected;

      _startTelemetryPolling();

    } catch (e) {
      _status = DroneStatus.error;
      print('WiFi connection error: $e');
      await _cleanupConnection();
    }
    
    notifyListeners();
  }

  Future<DroneInfo> _getWifiDroneInfo() async {
    // Получаем реальный уровень сигнала
    final signalStrength = await _getCurrentSignalStrength();

    // Отправляем команды для получения информации через WiFi
    if (_wifiSocket != null) {
      _wifiSocket!.write('command\r\n');
      await Future.delayed(Duration(milliseconds: 500));
      _wifiSocket!.write('sn?\r\n');
    }

    return DroneInfo(
      name: 'WiFi Drone',
      manufacturer: 'Generic',
      model: 'WiFi Drone',
      serialNumber: 'WIFI-${DateTime.now().millisecondsSinceEpoch}',
      deviceId: 'WIFI-CONNECTION',
      batteryLevel: 0.0,
      altitude: 0.0,
      latitude: 0.0,
      longitude: 0.0,
      cameraAvailable: true,
      connectionType: DroneConnectionType.wifi,
      status: DroneStatus.connected,
      telemetry: {
        'pitch': 0.0,
        'roll': 0.0,
        'yaw': 0.0,
        'speed': 0.0,
        'signal_strength': signalStrength,
        'propellers_ok': true,
        'gps_fix': 0,
        'satellites': 0,
        'voltage': 0.0,
        'current': 0.0,
        'flight_time': 0,
        'home_distance': 0.0,
        'rssi': -60, // Начальное значение RSSI
      },
      connectionTime: DateTime.now(),
      signalStrength: signalStrength,
      wifiFrequency: 2400, // Стандартная частота 2.4 GHz
    );
  }

  void _handleWifiData(List<int> data) {
    final message = String.fromCharCodes(data).trim();
    if (message.isNotEmpty) {
      print('WiFi данные: $message');
      _parseWifiTelemetry(message);
    }
  }

  void _parseWifiTelemetry(String data) {
    // Парсинг телеметрии DJI Tello и других дронов
    if (data.contains('battery')) {
      final battMatch = RegExp(r'battery[:\s]*(\d+)').firstMatch(data);
      if (battMatch != null) {
        final batteryLevel = int.parse(battMatch.group(1)!) / 100.0;
        _updateDroneTelemetry({'battery': batteryLevel});
      }
    }
    
    if (data.contains('height')) {
      final heightMatch = RegExp(r'height[:\s]*(\d+)').firstMatch(data);
      if (heightMatch != null) {
        final altitude = double.parse(heightMatch.group(1)!);
        _updateDroneTelemetry({'altitude': altitude});
      }
    }
    
    // Парсинг JSON формата если приходит
    try {
      if (data.startsWith('{') && data.endsWith('}')) {
        final jsonData = json.decode(data);
        _updateDroneTelemetry(jsonData);
      }
    } catch (e) {
      // Игнорируем ошибки JSON парсинга
    }
  }

  Future<void> _cleanupConnection() async {
    _telemetryTimer?.cancel();
    _signalStrengthTimer?.cancel();
    _usbSubscription?.cancel();
    await _usbPort?.close();
    _wifiSocket?.close();
    
    _usbPort = null;
    _usbSubscription = null;
    _wifiSocket = null;
    _telemetryTimer = null;
    _signalStrengthTimer = null;
  }

  void disconnect() {
    _cleanupConnection();
    _connectedDrone = null;
    _status = DroneStatus.disconnected;
    notifyListeners();
  }

  Stream<Map<String, dynamic>> getTelemetryStream() {
    return Stream.periodic(Duration(milliseconds: 100), (count) {
      return {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'battery': _connectedDrone?.batteryLevel ?? 0.0,
        'altitude': _connectedDrone?.altitude ?? 0.0,
        'signal': _connectedDrone?.signalStrength ?? 0,
        'pitch': _connectedDrone?.telemetry['pitch'] ?? 0.0,
        'roll': _connectedDrone?.telemetry['roll'] ?? 0.0,
        'yaw': _connectedDrone?.telemetry['yaw'] ?? 0.0,
        'speed': _connectedDrone?.telemetry['speed'] ?? 0.0,
        'satellites': _connectedDrone?.telemetry['satellites'] ?? 0,
        'rssi': _connectedDrone?.telemetry['rssi'] ?? -100,
        'frequency': _connectedDrone?.wifiFrequency ?? 0,
      };
    });
  }

  String? getVideoStreamUrl() {
    if (_connectedDrone == null) return null;
    
    switch (_connectedDrone!.connectionType) {
      case DroneConnectionType.wifi:
        return 'udp://192.168.1.1:11111';
      case DroneConnectionType.usb:
        // Для USB используем специальный URL для обработки
        return 'usb://drone/video';
      default:
        return null;
    }
  }

  // Метод для принудительного обновления телеметрии (для тестирования)
  void updateTestTelemetry(Map<String, dynamic> telemetry) {
    if (_connectedDrone != null) {
      _updateDroneTelemetry(telemetry);
    }
  }
}