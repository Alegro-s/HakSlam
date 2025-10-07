enum DatasetType { euroc, tum, custom }

class DatasetInfo {
  final DatasetType type;
  final String name;
  final String description;
  final String videoPath;
  final String? calibrationPath;
  final int totalFrames;
  final double fps;

  DatasetInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.videoPath,
    this.calibrationPath,
    required this.totalFrames,
    required this.fps,
  });
}

// Предопределенные датасеты
class PredefinedDatasets {
  static final eurocMachining = DatasetInfo(
    type: DatasetType.euroc,
    name: "EuRoC MAV - Machine Hall",
    description: "Промышленный цех с высокоточными данными",
    videoPath: "datasets/euroc/mav0/cam0/data",
    calibrationPath: "datasets/euroc/mav0/cam0/sensor.yaml",
    totalFrames: 2000,
    fps: 20.0,
  );

  static final eurocVicon = DatasetInfo(
    type: DatasetType.euroc,
    name: "EuRoC MAV - Vicon Room",
    description: "Комната с системой Vicon для точного отслеживания",
    videoPath: "datasets/euroc/mav1/cam0/data",
    calibrationPath: "datasets/euroc/mav1/cam0/sensor.yaml",
    totalFrames: 1500,
    fps: 20.0,
  );

  static final tumCorridor = DatasetInfo(
    type: DatasetType.tum,
    name: "TUM VI - Corridor",
    description: "Коридор с инерциальными данными",
    videoPath: "datasets/tum/corridor/mav0/cam0/data",
    calibrationPath: "datasets/tum/corridor/mav0/calibration.yaml",
    totalFrames: 1800,
    fps: 20.0,
  );

  static List<DatasetInfo> get all => [eurocMachining, eurocVicon, tumCorridor];
}