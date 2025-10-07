import 'package:flutter/material.dart';
import 'package:hakaton/core/services/dataset_service.dart';
import 'package:hakaton/core/services/drone_service.dart';
import 'package:hakaton/presentation/widgets/control_panel.dart';
import 'package:hakaton/presentation/widgets/video_panel.dart';
import 'package:hakaton/presentation/widgets/visualization_panel.dart';
import 'package:hakaton/presentation/widgets/drone_panel.dart';
import 'package:provider/provider.dart';

class SlamVisualizerPage extends StatefulWidget {
  const SlamVisualizerPage({super.key});

  @override
  State<SlamVisualizerPage> createState() => _SlamVisualizerPageState();
}

class _SlamVisualizerPageState extends State<SlamVisualizerPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final datasetService = Provider.of<DatasetService>(context);
    final droneService = Provider.of<DroneService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar, size: 24),
            SizedBox(width: 8),
            Text('SLAM 3D Visualizer'),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade900,
        elevation: 2,
        actions: [
          if (droneService.connectedDrone != null) ...[
            Icon(
              Icons.sensors,
              color: Colors.greenAccent,
            ),
            const SizedBox(width: 4),
            Text(
              "Дрон подключен",
              style: TextStyle(color: Colors.greenAccent),
            ),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.info_outline),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.help, size: 20),
                    SizedBox(width: 8),
                    Text('О программе'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'docs',
                child: Row(
                  children: [
                    Icon(Icons.menu_book, size: 20),
                    SizedBox(width: 8),
                    Text('Документация'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'about') {
                _showAboutDialog(context);
              }
            },
          ),
        ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Панель управления
                const ControlPanel(),
                
                // Панель дрона
                const DronePanel(),
                
                // Основное содержимое - адаптивная сетка
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 800;
                    
                    if (isWideScreen) {
                      // Desktop layout - горизонтальное расположение
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Левая колонка - видео
                            Expanded(
                              flex: 5,
                              child: Container(
                                constraints: BoxConstraints(
                                  minHeight: 400,
                                  maxHeight: constraints.maxHeight * 0.8,
                                ),
                                child: VideoPanel(
                                  videoPath: datasetService.selectedDataset?.videoPath,
                                  onVideoSelected: (path) {
                                    datasetService.addCustomDataset(path);
                                  },
                                ),
                              ),
                            ),
                            
                            // Правая колонка - 3D визуализация
                            Expanded(
                              flex: 5,
                              child: Container(
                                constraints: BoxConstraints(
                                  minHeight: 400,
                                  maxHeight: constraints.maxHeight * 0.8,
                                ),
                                child: const VisualizationPanel(),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Mobile layout - вертикальное расположение
                      return Column(
                        children: [
                          // Видео панель
                          Container(
                            constraints: BoxConstraints(
                              minHeight: 300,
                              maxHeight: constraints.maxHeight * 0.4,
                            ),
                            child: VideoPanel(
                              videoPath: datasetService.selectedDataset?.videoPath,
                              onVideoSelected: (path) {
                                datasetService.addCustomDataset(path);
                              },
                            ),
                          ),
                          
                          // 3D визуализация
                          Container(
                            constraints: BoxConstraints(
                              minHeight: 300,
                              maxHeight: constraints.maxHeight * 0.4,
                            ),
                            child: const VisualizationPanel(),
                          ),
                        ],
                      );
                    }
                  },
                ),
                
                // Отступ внизу для скроллинга
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.radar),
            SizedBox(width: 8),
            Text('SLAM 3D Visualizer'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Визуализатор SLAM алгоритмов для анализа видеопотоков с дронов.'),
              SizedBox(height: 16),
              Text('Поддерживаемые датасеты:'),
              Text('• EuRoC MAV Dataset'),
              Text('• TUM VI Dataset'),
              Text('• Пользовательские видео'),
              Text('• Прямой поток с дрона'),
              SizedBox(height: 16),
              Text(
                'Функциональность:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• 3D визуализация траектории и облака точек'),
              Text('• Реал-тайм обработка видео'),
              Text('• Поддержка реальных дронов (USB/WiFi/MAVLink)'),
              Text('• Статистика и анализ данных'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}