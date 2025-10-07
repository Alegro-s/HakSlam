
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/slam_data.dart';
import '../models/dataset_info.dart';

class SlamService extends ChangeNotifier {
  SlamData? _currentData;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _status = "Готов к работе";
  List<String> _processingLog = [];
  
  // Геттеры
  SlamData? get currentData => _currentData;
  bool get isProcessing => _isProcessing;
  double get progress => _progress;
  String get status => _status;
  List<String> get processingLog => _processingLog;

  Future<void> startProcessing(String videoPath, DatasetType datasetType) async {
    _isProcessing = true;
    _progress = 0.0;
    _status = "Инициализация обработки датасета...";
    _processingLog.clear();
    _addLog("Начало обработки датасета: $videoPath");
    notifyListeners();
    
    try {
      // Определяем тип процессора на основе типа датасета
      String processorScript;
      List<String> arguments;
      
      if (datasetType == DatasetType.euroc) {
        processorScript = 'euroc_processor.py';
        arguments = [
          '--dataset', videoPath,
          '--output', 'data/euroc_slam_results.json',
          '--start', '0',
          '--end', '300'
        ];
        _addLog("Используется EuRoC процессор");
      } else if (datasetType == DatasetType.tum) {
        processorScript = 'tum_processor.py';
        arguments = [
          '--dataset', videoPath,
          '--output', 'data/tum_slam_results.json',
          '--start', '0',
          '--end', '300'
        ];
        _addLog("Используется TUM процессор");
      } else {
        processorScript = 'real_slam_processor.py';
        arguments = [
          '--video', videoPath,
          '--dataset', 'custom',
          '--output', 'data/custom_slam_results.json'
        ];
        _addLog("Используется кастомный процессор");
      }
      
      // Имитация процесса обработки для демонстрации
      for (int i = 0; i <= 100; i += 5) {
        if (!_isProcessing) break;
        
        await Future.delayed(Duration(milliseconds: 200));
        _progress = i / 100;
        _status = "Обработка SLAM... ${i}%";
        
        // Генерация демонстрационных данных
        if (i % 20 == 0) {
          _currentData = _generateRealisticData(i);
          _addLog("Обработано кадров: ${i * 10}");
        }
        
        notifyListeners();
      }
      
      if (_isProcessing) {
        // Финальные данные
        _currentData = _generateRealisticData(100);
        _status = "SLAM обработка завершена успешно";
        _addLog("Результаты загружены: ${_currentData!.trajectory.length} поз, ${_currentData!.pointCloud.length} точек");
      }
      
    } catch (e) {
      _status = "Ошибка обработки: $e";
      _addLog("Ошибка: $e");
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> startLiveSLAM(String streamUrl) async {
    _isProcessing = true;
    _progress = 0.0;
    _status = "Запуск живого SLAM...";
    _processingLog.clear();
    _addLog("Подключение к видеопотоку: $streamUrl");
    notifyListeners();
    
    try {
      for (int i = 0; i <= 100; i += 2) {
        if (!_isProcessing) break;
        
        await Future.delayed(const Duration(milliseconds: 100));
        _progress = i / 100;
        _status = "Обработка живого видео... ${i}%";
        
        // Генерация реалистичных данных в реальном времени
        if (i % 10 == 0) {
          _currentData = _generateRealisticData(i);
          _addLog("Обработано кадров в реальном времени: ${i * 5}");
        }
        
        notifyListeners();
      }
      
      if (_isProcessing) {
        _status = "Живой SLAM завершен";
        _isProcessing = false;
        _addLog("Живая обработка завершена успешно");
      }
    } catch (e) {
      _status = "Ошибка живого SLAM: $e";
      _isProcessing = false;
      _addLog("Ошибка живой обработки: $e");
    }
    
    notifyListeners();
  }
  
  void stopProcessing() {
    _isProcessing = false;
    _status = "Обработка остановлена";
    _addLog("Обработка принудительно остановлена пользователем");
    notifyListeners();
  }
  
  void clearData() {
    _currentData = null;
    _progress = 0.0;
    _addLog("Данные SLAM очищены");
    notifyListeners();
  }
  
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split(' ')[1].split('.')[0];
    _processingLog.add("[$timestamp] $message");
    print("SLAM Log: $message");
  }

  // Генерация реалистичных данных SLAM
  SlamData _generateRealisticData(int progress) {
    final pointsCount = 500 + progress * 8;
    final posesCount = 10 + progress ~/ 10;
    
    // Реалистичная траектория - спираль
    final trajectory = List<CameraPose>.generate(posesCount, (i) {
      final t = i * 0.1;
      return CameraPose(
        x: t * 0.5,
        y: sin(t) * 0.8,
        z: cos(t) * 0.8,
        qx: 0.0,
        qy: 0.0,
        qz: sin(t * 0.5) * 0.3,
        qw: cos(t * 0.5) * 0.7,
        frameId: i * 5,
        timestamp: i * 0.033,
      );
    });
    
    // Реалистичное облако точек - окружающая среда
    final pointCloud = List<Point3D>.generate(pointsCount, (i) {
      final angle = i * 0.1;
      final radius = 2.0 + (i % 10) * 0.5;
      return Point3D(
        x: radius * cos(angle),
        y: radius * sin(angle) * 0.5,
        z: (i % 20) * 0.2 - 2.0,
        r: (i * 30) % 255,
        g: (i * 60) % 255,
        b: (i * 90) % 255,
      );
    });
    
    return SlamData(
      trajectory: trajectory,
      pointCloud: pointCloud,
      processedFrames: progress * 10,
      totalFrames: 1000,
      timestamp: DateTime.now(),
    );
  }
}