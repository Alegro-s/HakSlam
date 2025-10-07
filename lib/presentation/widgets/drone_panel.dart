import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hakaton/core/services/drone_service.dart';

class DronePanel extends StatelessWidget {
  const DronePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final droneService = Provider.of<DroneService>(context);
    final drone = droneService.connectedDrone;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(droneService),
            if (drone != null) ...[
              const SizedBox(height: 16),
              _buildDroneInfo(drone),
              const SizedBox(height: 16),
              _buildTelemetryPanel(drone),
              const SizedBox(height: 16),
              _buildCameraStatus(drone),
            ] else ...[
              const SizedBox(height: 16),
              _buildConnectionOptions(droneService, context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(DroneService droneService) {
    Color statusColor;
    String statusText;
    
    switch (droneService.status) {
      case DroneStatus.connected:
        statusColor = Colors.greenAccent;
        statusText = "ПОДКЛЮЧЕНО";
        break;
      case DroneStatus.connecting:
        statusColor = Colors.orangeAccent;
        statusText = "ПОДКЛЮЧЕНИЕ...";
        break;
      case DroneStatus.error:
        statusColor = Colors.redAccent;
        statusText = "ОШИБКА";
        break;
      case DroneStatus.scanning:
        statusColor = Colors.blueAccent;
        statusText = "ПОИСК ДРОНОВ...";
        break;
      default:
        statusColor = Colors.grey;
        statusText = "НЕТ ПОДКЛЮЧЕНИЯ";
    }

    return Row(
      children: [
        Icon(
          Icons.sensors,
          color: statusColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          "Статус дрона: ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade300,
          ),
        ),
        Text(
          statusText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDroneInfo(DroneInfo drone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Дрон: ${drone.name}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          "Модель: ${drone.model}",
          style: TextStyle(color: Colors.grey.shade400),
        ),
        Text(
          "Производитель: ${drone.manufacturer}",
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.battery_std,
              color: _getBatteryColor(drone.batteryLevel),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text("${(drone.batteryLevel * 100).toInt()}%"),
            const SizedBox(width: 16),
            Icon(
              Icons.wifi,
              color: drone.connectionType == DroneConnectionType.wifi 
                  ? Colors.greenAccent 
                  : Colors.blueAccent,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(drone.connectionType == DroneConnectionType.wifi 
                ? "WiFi" 
                : "USB"),
            const SizedBox(width: 16),
            Icon(
              Icons.signal_cellular_alt,
              color: _getSignalColor(drone.signalStrength),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text("${drone.signalStrength}%"),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryPanel(DroneInfo drone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Телеметрия:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTelemetryItem("Высота", "${drone.altitude.toStringAsFixed(1)}м"),
              _buildTelemetryItem("Крен", "${drone.telemetry['roll']?.toStringAsFixed(1) ?? '0'}°"),
              _buildTelemetryItem("Тангаж", "${drone.telemetry['pitch']?.toStringAsFixed(1) ?? '0'}°"),
              _buildTelemetryItem("Сигнал", "${drone.signalStrength}%"),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTelemetryItem("Скорость", "${drone.telemetry['speed']?.toStringAsFixed(1) ?? '0'}м/с"),
              _buildTelemetryItem("Спутники", "${drone.telemetry['satellites'] ?? '0'}"),
              _buildTelemetryItem("RSSI", "${drone.telemetry['rssi'] ?? '-100'}dBm"),
              _buildTelemetryItem("Частота", "${drone.wifiFrequency}MHz"),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: drone.telemetry['propellers_ok'] == true 
                    ? Colors.greenAccent 
                    : Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                "Пропеллеры: ${drone.telemetry['propellers_ok'] == true ? 'OK' : 'ПРОВЕРИТЬ'}",
                style: TextStyle(
                  color: drone.telemetry['propellers_ok'] == true 
                      ? Colors.greenAccent 
                      : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.gps_fixed,
                color: (drone.telemetry['gps_fix'] as int? ?? 0) > 0 
                    ? Colors.greenAccent 
                    : Colors.orangeAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                "GPS: ${(drone.telemetry['gps_fix'] as int? ?? 0) > 0 ? 'FIX' : 'NO FIX'}",
                style: TextStyle(
                  color: (drone.telemetry['gps_fix'] as int? ?? 0) > 0 
                      ? Colors.greenAccent 
                      : Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCameraStatus(DroneInfo drone) {
    return Row(
      children: [
        Icon(
          Icons.videocam,
          color: drone.cameraAvailable ? Colors.greenAccent : Colors.redAccent,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          drone.cameraAvailable 
              ? "Камера доступна" 
              : "Камера недоступна",
          style: TextStyle(
            color: drone.cameraAvailable ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
        if (drone.cameraAvailable) ...[
          const SizedBox(width: 16),
          Icon(
            Icons.video_call,
            color: Colors.blueAccent,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            "Поток: ${drone.connectionType == DroneConnectionType.wifi ? 'UDP' : 'USB'}",
            style: TextStyle(color: Colors.blueAccent),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionOptions(DroneService droneService, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Подключение дрона:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.usb),
                label: const Text("USB"),
                onPressed: () => _connectViaUSB(droneService, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.wifi),
                label: const Text("WiFi"),
                onPressed: () => _showWifiConnectionDialog(context, droneService),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text("Сканировать USB устройства"),
          onPressed: () => droneService.scanForDrones(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent.shade700,
          ),
        ),
        if (droneService.discoveredDrones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            "Обнаружено устройств: ${droneService.discoveredDrones.length}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          ...droneService.discoveredDrones.map((device) => ListTile(
  leading: const Icon(Icons.usb, size: 20),
  title: Text(device.deviceName),
  subtitle: Text('VID: 0x${device.vid?.toRadixString(16) ?? 'unknown'}, PID: 0x${device.pid?.toRadixString(16) ?? 'unknown'}'),
  trailing: ElevatedButton(
    onPressed: () => droneService.connectToDrone(device),
    child: const Text('Подключить'),
  ),
)).toList(),
        ],
      ],
    );
  }

  Future<void> _connectViaUSB(DroneService droneService, BuildContext context) async {
    try {
      await droneService.connectViaUSB();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка подключения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWifiConnectionDialog(BuildContext context, DroneService droneService) {
    final ssidController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Подключение по WiFi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(
                labelText: "SSID сети дрона",
                hintText: "DJI_XXXXXX",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Пароль",
                hintText: "1234567890",
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final ssid = ssidController.text.trim();
              final password = passwordController.text.trim();
              if (ssid.isNotEmpty) {
                droneService.connectViaWifi(ssid, password);
              }
            },
            child: const Text("Подключить"),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(double level) {
    if (level > 0.7) return Colors.greenAccent;
    if (level > 0.3) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getSignalColor(int strength) {
    if (strength > 75) return Colors.greenAccent;
    if (strength > 50) return Colors.orangeAccent;
    if (strength > 25) return Colors.orange;
    return Colors.redAccent;
  }
}