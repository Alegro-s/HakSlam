import 'package:flutter/material.dart';
import '../models/dataset_info.dart';

class DatasetService extends ChangeNotifier {
  DatasetInfo? _selectedDataset;
  List<DatasetInfo> _availableDatasets = [];
  
  DatasetInfo? get selectedDataset => _selectedDataset;
  List<DatasetInfo> get availableDatasets => _availableDatasets;
  
  DatasetService() {
    _initializeDatasets();
  }
  
  void _initializeDatasets() {
    _availableDatasets = [
      // EuRoC MAV Datasets
      DatasetInfo(
        type: DatasetType.euroc,
        name: "EuRoC - Machine Hall 01 (Easy)",
        description: "Промышленный цех - легкий маршрут",
        videoPath: "datasets/euroc/MH_01_easy/mav0/cam0/data",
        calibrationPath: "datasets/euroc/MH_01_easy/mav0/cam0/sensor.yaml",
        totalFrames: 3715,
        fps: 20.0,
      ),
      DatasetInfo(
        type: DatasetType.euroc,
        name: "EuRoC - Vicon Room 01 (Easy)",
        description: "Комната Vicon - легкий маршрут",
        videoPath: "datasets/euroc/V1_01_easy/mav0/cam0/data",
        calibrationPath: "datasets/euroc/V1_01_easy/mav0/cam0/sensor.yaml",
        totalFrames: 3027,
        fps: 20.0,
      ),
      DatasetInfo(
        type: DatasetType.euroc,
        name: "EuRoC - Machine Hall 02 (Medium)",
        description: "Промышленный цех - средний маршрут",
        videoPath: "datasets/euroc/MH_02_easy/mav0/cam0/data",
        calibrationPath: "datasets/euroc/MH_02_easy/mav0/cam0/sensor.yaml",
        totalFrames: 3833,
        fps: 20.0,
      ),
      
      // TUM VI Datasets
      DatasetInfo(
        type: DatasetType.tum,
        name: "TUM VI - Room 1",
        description: "Комната с инерциальными данными",
        videoPath: "datasets/tum/dataset-room1_512_16/mav0/cam0/data",
        calibrationPath: "datasets/tum/dataset-room1_512_16/mav0/calibration.yaml",
        totalFrames: 2412,
        fps: 20.0,
      ),
      DatasetInfo(
        type: DatasetType.tum,
        name: "TUM VI - Corridor 1",
        description: "Коридор с инерциальными данными",
        videoPath: "datasets/tum/dataset-corridor1_512_16/mav0/cam0/data",
        calibrationPath: "datasets/tum/dataset-corridor1_512_16/mav0/calibration.yaml",
        totalFrames: 2876,
        fps: 20.0,
      ),
    ];
    
    // Проверяем доступность датасетов
    _checkDatasetAvailability();
  }
  
  void _checkDatasetAvailability() {
    // В реальном приложении здесь должна быть проверка существования файлов
    print("Доступные датасеты: ${_availableDatasets.length}");
  }
  
  void selectDataset(DatasetInfo dataset) {
    _selectedDataset = dataset;
    print("Выбран датасет: ${dataset.name}");
    notifyListeners();
  }
  
  void addCustomDataset(String videoPath) {
    final customDataset = DatasetInfo(
      type: DatasetType.custom,
      name: "Пользовательское видео",
      description: "Загруженное пользователем видео",
      videoPath: videoPath,
      totalFrames: 1000,
      fps: 30.0,
    );
    
    _availableDatasets.add(customDataset);
    _selectedDataset = customDataset;
    notifyListeners();
  }
  
  // Метод для получения абсолютного пути к датасету
  String getDatasetFullPath(DatasetInfo dataset) {
    return dataset.videoPath;
  }
}