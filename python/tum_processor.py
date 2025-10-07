import os
import cv2
import numpy as np
import json
import yaml
from pathlib import Path
from datetime import datetime

class TUMDatasetProcessor:
    def __init__(self, dataset_path):
        self.dataset_path = Path(dataset_path)
        self.cam0_path = self.dataset_path / "mav0" / "cam0" / "data"
        self.imu_path = self.dataset_path / "mav0" / "imu0" / "data.csv"
        
        self.timestamps = self._load_timestamps()
        self.camera_params = self._load_camera_parameters()
        self.current_frame = 0
        
        print(f"Инициализирован обработчик TUM датасета: {dataset_path}")
        print(f"Найдено кадров: {len(self.timestamps)}")
        
    def _load_timestamps(self):
        """Загрузка временных меток из TUM датасета"""
        timestamps = []
        timestamp_file = self.cam0_path / "../data.csv"
        
        if timestamp_file.exists():
            with open(timestamp_file, 'r') as f:
                lines = f.readlines()[1:]
                for line in lines:
                    parts = line.strip().split(',')
                    if len(parts) >= 1:
                        timestamp_ns = int(parts[0])
                        timestamp_s = timestamp_ns / 1e9
                        timestamps.append(timestamp_s)
        else:
            image_files = sorted(self.cam0_path.glob("*.png"))
            timestamps = [i * 0.05 for i in range(len(image_files))]
        
        return timestamps
    
    def _load_camera_parameters(self):
        """Загрузка калибровочных параметров камеры для TUM"""
        camera_params = {
            'cam0': {},
            'cam1': {}
        }
        
        # Параметры по умолчанию для TUM VI
        camera_params['cam0'] = {
            'intrinsics': [450.0, 450.0, 320.0, 240.0],
            'resolution': [640, 480],
            'distortion_coeffs': [0.0, 0.0, 0.0, 0.0, 0.0]
        }
        
        return camera_params
    
    def get_camera_matrix(self):
        """Получение матрицы камеры"""
        intrinsics = self.camera_params['cam0']['intrinsics']
        return np.array([
            [intrinsics[0], 0, intrinsics[2]],
            [0, intrinsics[1], intrinsics[3]],
            [0, 0, 1]
        ])
    
    def get_total_frames(self):
        return len(self.timestamps)
    
    def get_frame(self, frame_index):
        if frame_index >= len(self.timestamps):
            return None, None
            
        image_files = sorted(self.cam0_path.glob("*.png"))
        if frame_index >= len(image_files):
            return None, None
            
        image_path = image_files[frame_index]
        image = cv2.imread(str(image_path))
        
        if image is None:
            return None, None
            
        timestamp = self.timestamps[frame_index]
        self.current_frame = frame_index
        
        return image, timestamp
    
    def process_sequence(self, start_frame=0, end_frame=None, output_path="tum_results.json"):
        """Обработка последовательности TUM датасета"""
        if end_frame is None:
            end_frame = self.get_total_frames()
        else:
            end_frame = min(end_frame, self.get_total_frames())
            
        results = {
            'dataset': str(self.dataset_path),
            'processed_frames': 0,
            'total_frames': self.get_total_frames(),
            'trajectory': [],
            'point_cloud': [],
            'processing_start': datetime.now().isoformat(),
            'camera_parameters': self.camera_params['cam0']
        }
        
        print(f"Начало обработки TUM кадров {start_frame}-{end_frame}")
        
        for frame_idx in range(start_frame, end_frame):
            frame, timestamp = self.get_frame(frame_idx)
            if frame is None:
                continue
                
            # Имитация SLAM обработки
            frame_result = self._process_slam_frame(frame, frame_idx, timestamp)
            
            if frame_result:
                results['trajectory'].append(frame_result['pose'])
                if 'points' in frame_result:
                    results['point_cloud'].extend(frame_result['points'])
                    
            results['processed_frames'] = frame_idx + 1
            
            if frame_idx % 50 == 0:
                self._save_progress(results, output_path, frame_idx)
                print(f"Обработано TUM: {frame_idx}/{end_frame}")
                
        results['processing_end'] = datetime.now().isoformat()
        self._save_results(results, output_path)
        
        return results
    
    def _process_slam_frame(self, frame, frame_idx, timestamp):
        """Обработка одного кадра через SLAM для TUM"""
        # Используем наш реальный SLAM процессор
        from real_slam_processor import MonoSLAM
        
        if not hasattr(self, 'slam_processor'):
            camera_matrix = self.get_camera_matrix()
            self.slam_processor = MonoSLAM()
            self.slam_processor.camera_matrix = camera_matrix
            
        slam_result = self.slam_processor.process_frame(frame, frame_idx)
        
        if slam_result:
            return {
                'pose': slam_result['pose'],
                'points': slam_result['points']
            }
        return None
    
    def _save_progress(self, results, output_path, frame_idx):
        progress_file = Path(output_path).with_suffix(f'.progress_{frame_idx}.json')
        with open(progress_file, 'w') as f:
            json.dump(results, f, indent=2, default=self._json_serializer)
    
    def _save_results(self, results, output_path):
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2, default=self._json_serializer)
    
    def _json_serializer(self, obj):
        if isinstance(obj, (np.int_, np.intc, np.intp, np.int8,
                          np.int16, np.int32, np.int64, np.uint8,
                          np.uint16, np.uint32, np.uint64)):
            return int(obj)
        elif isinstance(obj, (np.float_, np.float16, np.float32, np.float64)):
            return float(obj)
        elif isinstance(obj, (np.ndarray,)):
            return obj.tolist()
        elif isinstance(obj, Path):
            return str(obj)
        return str(obj)

def process_tum_dataset(dataset_path, output_path, start_frame=0, end_frame=None):
    """Основная функция для обработки TUM датасета"""
    processor = TUMDatasetProcessor(dataset_path)
    results = processor.process_sequence(start_frame, end_frame, output_path)
    
    print(f"\nОбработка TUM датасета завершена!")
    print(f"Датасет: {dataset_path}")
    print(f"Обработано кадров: {results['processed_frames']}")
    print(f"Точек в облаке: {len(results['point_cloud'])}")
    print(f"Поз в траектории: {len(results['trajectory'])}")
    
    return results

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Process TUM VI Dataset')
    parser.add_argument('--dataset', type=str, required=True, help='Path to TUM dataset folder')
    parser.add_argument('--output', type=str, required=True, help='Output JSON path')
    parser.add_argument('--start', type=int, default=0, help='Start frame')
    parser.add_argument('--end', type=int, default=None, help='End frame')
    
    args = parser.parse_args()
    
    process_tum_dataset(args.dataset, args.output, args.start, args.end)