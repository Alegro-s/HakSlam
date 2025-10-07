class SlamData {
  final List<CameraPose> trajectory;
  final List<Point3D> pointCloud;
  final int processedFrames;
  final int totalFrames;
  final DateTime timestamp;

  SlamData({
    required this.trajectory,
    required this.pointCloud,
    required this.processedFrames,
    required this.totalFrames,
    required this.timestamp,
  });

  factory SlamData.fromJson(Map<String, dynamic> json) {
    return SlamData(
      trajectory: (json['trajectory'] as List)
          .map((pose) => CameraPose.fromJson(pose))
          .toList(),
      pointCloud: (json['point_cloud'] as List)
          .map((point) => Point3D.fromJson(point))
          .toList(),
      processedFrames: json['processed_frames'],
      totalFrames: json['total_frames'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class CameraPose {
  final double x, y, z;
  final double qx, qy, qz, qw; // кватернион
  final int frameId;
  final double timestamp;

  CameraPose({
    required this.x,
    required this.y,
    required this.z,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
    required this.frameId,
    required this.timestamp,
  });

  factory CameraPose.fromJson(Map<String, dynamic> json) {
    return CameraPose(
      x: json['x']?.toDouble() ?? 0.0,
      y: json['y']?.toDouble() ?? 0.0,
      z: json['z']?.toDouble() ?? 0.0,
      qx: json['qx']?.toDouble() ?? 0.0,
      qy: json['qy']?.toDouble() ?? 0.0,
      qz: json['qz']?.toDouble() ?? 0.0,
      qw: json['qw']?.toDouble() ?? 1.0,
      frameId: json['frame_id'] ?? 0,
      timestamp: json['timestamp']?.toDouble() ?? 0.0,
    );
  }
}

class Point3D {
  final double x, y, z;
  final int r, g, b; // цвет точки

  Point3D({
    required this.x,
    required this.y,
    required this.z,
    this.r = 100,
    this.g = 150,
    this.b = 255,
  });

  factory Point3D.fromJson(Map<String, dynamic> json) {
    return Point3D(
      x: json['x']?.toDouble() ?? 0.0,
      y: json['y']?.toDouble() ?? 0.0,
      z: json['z']?.toDouble() ?? 0.0,
      r: json['r'] ?? 100,
      g: json['g'] ?? 150,
      b: json['b'] ?? 255,
    );
  }
}