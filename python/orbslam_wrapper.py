import subprocess
import json
import os
from pathlib import Path

class ORBSLAMWrapper:
    def __init__(self, vocab_path, config_path):
        self.vocab_path = vocab_path
        self.config_path = config_path
        self.trajectory = []
        self.point_cloud = []
    
    def process_video(self, video_path, output_dir):
        """Запуск ORB-SLAM3 на видеофайле"""
        
        # Создаем выходную директорию
        output_dir = Path(output_dir)
        output_dir.mkdir(exist_ok=True)
        
        # Запускаем ORB-SLAM3
        cmd = [
            "./ORB_SLAM3/Examples/Monocular/mono_euroc",
            self.vocab_path,
            self.config_path,
            str(video_path),
            str(output_dir / "trajectory.txt"),
            str(output_dir / "point_cloud.ply")
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                return self._parse_results(output_dir)
            else:
                print(f"ORB-SLAM3 error: {result.stderr}")
                return None
        except Exception as e:
            print(f"Failed to run ORB-SLAM3: {e}")
            return None
    
    def _parse_results(self, output_dir):
        """Парсинг результатов ORB-SLAM3"""
        
        # Парсинг траектории
        trajectory_path = output_dir / "trajectory.txt"
        if trajectory_path.exists():
            self.trajectory = self._parse_trajectory(trajectory_path)
        
        # Парсинг облака точек
        point_cloud_path = output_dir / "point_cloud.ply"
        if point_cloud_path.exists():
            self.point_cloud = self._parse_point_cloud(point_cloud_path)
        
        return {
            'trajectory': self.trajectory,
            'point_cloud': self.point_cloud,
            'processed_frames': len(self.trajectory),
            'total_frames': self._estimate_total_frames()
        }
    
    def _parse_trajectory(self, file_path):
        """Парсинг файла траектории ORB-SLAM3"""
        trajectory = []
        with open(file_path, 'r') as f:
            for line in f:
                if line.startswith('#'):
                    continue
                values = list(map(float, line.strip().split()))
                if len(values) >= 8:  # timestamp, x, y, z, qx, qy, qz, qw
                    pose = {
                        'timestamp': values[0],
                        'x': values[1], 'y': values[2], 'z': values[3],
                        'qx': values[4], 'qy': values[5], 'qz': values[6], 'qw': values[7],
                        'frame_id': len(trajectory)
                    }
                    trajectory.append(pose)
        return trajectory
    
    def _parse_point_cloud(self, file_path):
        """Парсинг PLY файла облака точек"""
        points = []
        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
            
            # Находим начало данных
            data_start = 0
            for i, line in enumerate(lines):
                if "end_header" in line:
                    data_start = i + 1
                    break
            
            # Парсим точки
            for line in lines[data_start:]:
                values = list(map(float, line.strip().split()))
                if len(values) >= 6:  # x, y, z, r, g, b
                    point = {
                        'x': values[0], 'y': values[1], 'z': values[2],
                        'r': int(values[3]), 'g': int(values[4]), 'b': int(values[5])
                    }
                    points.append(point)
        
        except Exception as e:
            print(f"Error parsing point cloud: {e}")
        
        return points
    
    def _estimate_total_frames(self):
        """Оценка общего количества кадров"""
        # Можно получить из метаданных видео
        return len(self.trajectory) * 2  # Примерная оценка