import 'package:flutter/material.dart';
import 'package:hakaton/core/models/dataset_info.dart';
import 'package:hakaton/core/services/dataset_service.dart';
import 'package:hakaton/core/services/slam_service.dart';
import 'package:hakaton/core/services/drone_service.dart';
import 'package:provider/provider.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final slamService = Provider.of<SlamService>(context);
    final datasetService = Provider.of<DatasetService>(context);
    final droneService = Provider.of<DroneService>(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Выбор датасета
            _buildDatasetSelector(datasetService),
            const SizedBox(height: 16),
            
            // Индикатор прогресса
            _buildProgressIndicator(slamService),
            const SizedBox(height: 16),
            
            // Кнопки управления
            _buildControlButtons(slamService, datasetService, droneService, context),
            const SizedBox(height: 16),
            
            // Панель статистики
            _buildStatsPanel(slamService),
            const SizedBox(height: 8),
            
            // Лог обработки
            _buildProcessingLog(slamService),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetSelector(DatasetService datasetService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Выбор датасета:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade800,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade600),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<DatasetInfo>(
              value: datasetService.selectedDataset,
              isExpanded: true,
              dropdownColor: Colors.blueGrey.shade800,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Colors.blueGrey.shade300),
              hint: const Text(
                "Выберите датасет",
                style: TextStyle(color: Colors.grey),
              ),
              items: datasetService.availableDatasets.map((dataset) {
                return DropdownMenuItem<DatasetInfo>(
                  value: dataset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _getDatasetIcon(dataset.type),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dataset.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dataset.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${dataset.totalFrames} кадров • ${dataset.fps} FPS",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade300,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (DatasetInfo? dataset) {
                if (dataset != null) {
                  datasetService.selectDataset(dataset);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(SlamService slamService) {
    Color statusColor;
    IconData statusIcon;
    
    if (slamService.isProcessing) {
      statusColor = Colors.blueAccent;
      statusIcon = Icons.autorenew;
    } else if (slamService.currentData != null) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Text(
              "Статус: ${slamService.status}",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: slamService.progress,
          backgroundColor: Colors.grey.shade800,
          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${(slamService.progress * 100).toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
            if (slamService.currentData != null)
              Text(
                "${slamService.currentData!.processedFrames}/${slamService.currentData!.totalFrames} кадров",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButtons(
    SlamService slamService,
    DatasetService datasetService,
    DroneService droneService,
    BuildContext context,
  ) {
    final hasDrone = droneService.connectedDrone != null;
    final hasDataset = datasetService.selectedDataset != null;
    final isProcessing = slamService.isProcessing;

    return Column(
      children: [
        // Основные кнопки управления
        Row(
          children: [
            if (hasDrone) ...[
              Expanded(
                child: _buildControlButton(
                  icon: Icons.live_tv,
                  label: "Живой SLAM с дрона",
                  color: Colors.orangeAccent,
                  onPressed: isProcessing
                      ? null
                      : () {
                          final streamUrl = droneService.getVideoStreamUrl();
                          if (streamUrl != null) {
                            slamService.startLiveSLAM(streamUrl);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Видеопоток с дрона недоступен'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            if (hasDataset) ...[
              Expanded(
                child: _buildControlButton(
                  icon: Icons.play_arrow,
                  label: "SLAM с датасета",
                  color: Colors.greenAccent,
                  onPressed: isProcessing
                      ? null
                      : () => slamService.startProcessing(
                            datasetService.selectedDataset!.videoPath,
                            datasetService.selectedDataset!.type,
                          ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            Expanded(
              child: _buildControlButton(
                icon: Icons.stop,
                label: "Стоп",
                color: Colors.redAccent,
                onPressed: isProcessing ? () => slamService.stopProcessing() : null,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Дополнительные кнопки
        Row(
          children: [
            Expanded(
              child: _buildControlButton(
                icon: Icons.clear,
                label: "Очистить данные",
                color: Colors.grey,
                onPressed: slamService.currentData != null ? () => slamService.clearData() : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildControlButton(
                icon: Icons.refresh,
                label: "Перезапуск",
                color: Colors.blueAccent,
                onPressed: () {
                  slamService.clearData();
                  if (hasDataset) {
                    slamService.startProcessing(
                      datasetService.selectedDataset!.videoPath,
                      datasetService.selectedDataset!.type,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : Colors.grey.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildStatsPanel(SlamService slamService) {
    final data = slamService.currentData;
    
    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            "Нет данных SLAM",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Статистика SLAM:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem(
                "Кадры",
                "${data.processedFrames}/${data.totalFrames}",
                Icons.videocam,
              ),
              _buildStatItem(
                "Точки",
                data.pointCloud.length.toString(),
                Icons.grain,
              ),
              _buildStatItem(
                "Позы",
                data.trajectory.length.toString(),
                Icons.timeline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem(
                "Прогресс",
                "${(data.processedFrames / data.totalFrames * 100).toStringAsFixed(1)}%",
                Icons.percent,
              ),
              _buildStatItem(
                "Время",
                _formatTimestamp(data.timestamp),
                Icons.access_time,
              ),
              _buildStatItem(
                "Скорость",
                "${(data.processedFrames / 10).toStringAsFixed(1)} FPS",
                Icons.speed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.blueGrey.shade300),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingLog(SlamService slamService) {
    if (slamService.processingLog.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "📝 Лог обработки:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade700),
          ),
          child: ListView.builder(
            itemCount: slamService.processingLog.length,
            reverse: true,
            itemBuilder: (context, index) {
              final logIndex = slamService.processingLog.length - 1 - index;
              final log = slamService.processingLog[logIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  log,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontFamily: 'Monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Вспомогательные методы
  Icon _getDatasetIcon(DatasetType type) {
    switch (type) {
      case DatasetType.euroc:
        return const Icon(Icons.precision_manufacturing, size: 16, color: Colors.blueAccent);
      case DatasetType.tum:
        return const Icon(Icons.school, size: 16, color: Colors.greenAccent);
      case DatasetType.custom:
        return const Icon(Icons.video_library, size: 16, color: Colors.orangeAccent);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return "Только что";
    if (difference.inHours < 1) return "${difference.inMinutes} мин";
    if (difference.inDays < 1) return "${difference.inHours} ч";
    return "${difference.inDays} д";
  }
}