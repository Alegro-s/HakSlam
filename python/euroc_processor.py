import os
import cv2
import numpy as np
import json
import yaml
from pathlib import Path
from datetime import datetime

class EurocDatasetProcessor:
    def __init__(self, dataset_path):
        self.dataset_path = Path(dataset_path)
        self.cam0_path = self.dataset_path / "cam0" / "data"
        self.cam1_path = self.dataset_path / "cam1" / "data"
        self.imu_path = self.dataset_path / "imu0" / "data.csv"
        
        self.timestamps = self._load_timestamps()
        self.camera_params = self._load_camera_parameters()
        self.current_frame = 0
        
        print(f"Инициализирован обработчик EuRoC датасета: {dataset_path}")
        print(f"Найдено кадров: {len(self.timestamps)}")
        
    def _load_timestamps(self):
        """Загрузка временных меток из EuRoC датасета"""
        timestamps = []
        timestamp_file = self.cam0_path / "../data.csv"
        
        if timestamp_file.exists():
            with open(timestamp_file, 'r') as f:
                lines = f.readlines()[1:]  # Пропускаем заголовок
                for line in lines:
                    parts = line.strip().split(',')
                    if len(parts) >= 1:
                        timestamp_ns = int(parts[0])
                        timestamp_s = timestamp_ns / 1e9  # Конвертация в секунды
                        timestamps.append(timestamp_s)
        else:
            # Если файл с временными метками не найден, используем имена файлов
            image_files = sorted(self.cam0_path.glob("*.png"))
            timestamps = [i * 0.05 for i in range(len(image_files))]  # 20 FPS
        
        return timestamps
    
    def _load_camera_parameters(self):
        """Загрузка калибровочных параметров камеры"""
        camera_params = {
            'cam0': {},
            'cam1': {}
        }
        
        # Загрузка параметров для cam0
        cam0_calib = self.dataset_path / "cam0" / "sensor.yaml"
        if cam0_calib.exists():
            with open(cam0_calib, 'r') as f:
                cam0_data = yaml.safe_load(f)
                if 'intrinsics' in cam0_data:
                    camera_params['cam0']['intrinsics'] = cam0_data['intrinsics']
                if 'resolution' in cam0_data:
                    camera_params['cam0']['resolution'] = cam0_data['resolution']
        
        # Параметры по умолчанию для EuRoC
        if not camera_params['cam0']:
            camera_params['cam0'] = {
                'intrinsics': [458.654, 457.296, 367.215, 248.375],
                'resolution': [752, 480],
                'distortion_coeffs': [-0.28340811, 0.07395907, 0.00019359, 1.76187114e-05]
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
        """Получение общего количества кадров"""
        return len(self.timestamps)
    
    def get_frame(self, frame_index):
        """Получение кадра по индексу"""
        if frame_index >= len(self.timestamps):
            return None, None
            
        # Поиск файла изображения
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
    
    def get_stereo_frame(self, frame_index):
        """Получение стерео пары кадров"""
        image0, timestamp = self.get_frame(frame_index)
        if image0 is None:
            return None, None, None
            
        # Получение второго кадра для стерео
        image_files1 = sorted(self.cam1_path.glob("*.png"))
        if frame_index >= len(image_files1):
            return image0, None, timestamp
            
        image1_path = image_files1[frame_index]
        image1 = cv2.imread(str(image1_path))
        
        return image0, image1, timestamp
    
    def process_sequence(self, start_frame=0, end_frame=None, output_path="euroc_results.json"):
        """Обработка последовательности кадров"""
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
        
        print(f"Начало обработки кадров {start_frame}-{end_frame}")
        
        for frame_idx in range(start_frame, end_frame):
            frame, timestamp = self.get_frame(frame_idx)
            if frame is None:
                continue
                
            # Здесь будет вызов SLAM обработки
            frame_result = self._process_slam_frame(frame, frame_idx, timestamp)
            
            if frame_result:
                results['trajectory'].append(frame_result['pose'])
                if 'points' in frame_result:
                    results['point_cloud'].extend(frame_result['points'])
                    
            results['processed_frames'] = frame_idx + 1
            
            # Сохранение прогресса каждые 50 кадров
            if frame_idx % 50 == 0:
                self._save_progress(results, output_path, frame_idx)
                print(f"Обработано: {frame_idx}/{end_frame}")
                
        results['processing_end'] = datetime.now().isoformat()
        self._save_results(results, output_path)
        
        return results
    
    def _process_slam_frame(self, frame, frame_idx, timestamp):
        """Обработка одного кадра через SLAM"""
        # Используем наш реальный SLAM процессор
        from real_slam_processor import MonoSLAM
        
        # Инициализация SLAM при первом кадре
        if not hasattr(self, 'slam_processor'):
            camera_matrix = self.get_camera_matrix()
            self.slam_processor = MonoSLAM()
            self.slam_processor.camera_matrix = camera_matrix
            
        # Обработка кадра
        slam_result = self.slam_processor.process_frame(frame, frame_idx)
        
        if slam_result:
            return {
                'pose': slam_result['pose'],
                'points': slam_result['points']
            }
        return None
    
    def _save_progress(self, results, output_path, frame_idx):
        """Сохранение промежуточных результатов"""
        progress_file = Path(output_path).with_suffix(f'.progress_{frame_idx}.json')
        with open(progress_file, 'w') as f:
            json.dump(results, f, indent=2, default=self._json_serializer)
    
    def _save_results(self, results, output_path):
        """Сохранение финальных результатов"""
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2, default=self._json_serializer)
    
    def _json_serializer(self, obj):
        """Сериализатор для numpy типов"""
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

def process_euroc_dataset(dataset_path, output_path, start_frame=0, end_frame=None):
    """Основная функция для обработки EuRoC датасета"""
    processor = EurocDatasetProcessor(dataset_path)
    results = processor.process_sequence(start_frame, end_frame, output_path)
    
    print(f"\nОбработка EuRoC датасета завершена!")
    print(f"Датасет: {dataset_path}")
    print(f"Обработано кадров: {results['processed_frames']}")
    print(f"Точек в облаке: {len(results['point_cloud'])}")
    print(f"Поз в траектории: {len(results['trajectory'])}")
    
    return results

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Process EuRoC MAV Dataset')
    parser.add_argument('--dataset', type=str, required=True, help='Path to Euroc dataset folder')
    parser.add_argument('--output', type=str, required=True, help='Output JSON path')
    parser.add_argument('--start', type=int, default=0, help='Start frame')
    parser.add_argument('--end', type=int, default=None, help='End frame')
    
    args = parser.parse_args()
    
    process_euroc_dataset(args.dataset, args.output, args.start, args.end)