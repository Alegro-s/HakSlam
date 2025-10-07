import json
import os
import cv2
import numpy as np
from pathlib import Path
from typing import List, Dict, Any
import argparse

class SlamProcessor:
    def __init__(self, dataset_type: str):
        self.dataset_type = dataset_type
        self.trajectory = []
        self.point_cloud = []
        self.processed_frames = 0
        
    def process_video(self, video_path: str, output_path: str = None):
        """Обработка видео и генерация SLAM данных"""
        
        # Загрузка видео
        cap = cv2.VideoCapture(video_path)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        results = {
            'trajectory': [],
            'point_cloud': [],
            'processed_frames': 0,
            'total_frames': total_frames
        }
        
        frame_count = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            # Имитация обработки SLAM
            slam_data = self._process_frame(frame, frame_count)
            
            if slam_data:
                results['trajectory'].append(slam_data['pose'])
                results['point_cloud'].extend(slam_data['points'])
                results['processed_frames'] = frame_count
                
            frame_count += 1
            
            # Сохранение промежуточных результатов каждые 10 кадров
            if frame_count % 10 == 0 and output_path:
                self._save_intermediate_results(results, output_path, frame_count)
                
        cap.release()
        
        # Финальное сохранение
        if output_path:
            self._save_results(results, output_path)
            
        return results
    def _load_config(self, config_path):
        """Загрузка конфигурации из YAML файла"""
        if config_path and os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    return yaml.safe_load(f)
            except Exception as e:
                print(f"Error loading config: {e}")
        
        # Конфигурация по умолчанию
        return {
            'Camera': {
                'width': 752,
                'height': 480,
                'fps': 20.0
            },
            'ORB': {
                'nFeatures': 1000,
                'scaleFactor': 1.2
            }
        }
    
    def process_video(self, video_path, dataset_type="euroc"):
        """Обработка с учетом конфигурации"""
        
        config_file = f"config/{dataset_type}_config.yaml"
        if os.path.exists(config_file):
            self.config = self._load_config(config_file)
            print(f"Используется конфигурация: {config_file}")
    
    def _process_frame(self, frame: np.ndarray, frame_id: int) -> Dict[str, Any]:
        """Обработка одного кадра (имитация SLAM алгоритма)"""
        
        # Имитация обнаружения особенностей
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Детектор углов (имитация ORB features)
        detector = cv2.FastFeatureDetector_create()
        keypoints = detector.detect(gray, None)
        
        # Генерация позы камеры (имитация)
        pose = {
            'x': frame_id * 0.1,
            'y': np.sin(frame_id * 0.05) * 2,
            'z': np.cos(frame_id * 0.05) * 2,
            'qx': 0.0, 'qy': 0.0, 'qz': 0.0, 'qw': 1.0,
            'frame_id': frame_id,
            'timestamp': frame_id * 0.033  # ~30 FPS
        }
        
        # Генерация облака точек (имитация)
        points = []
        for kp in keypoints[:50]:  # Ограничиваем количество точек
            point = {
                'x': kp.pt[0] * 0.01 - 2.5,
                'y': kp.pt[1] * 0.01 - 2.0,
                'z': (frame_id % 10) * 0.1,
                'r': int(kp.response * 255) if hasattr(kp, 'response') else 100,
                'g': 150,
                'b': 200
            }
            points.append(point)
            
        return {
            'pose': pose,
            'points': points
        }
    
    def _save_intermediate_results(self, results: Dict, output_path: str, frame_count: int):
        """Сохранение промежуточных результатов"""
        intermediate_file = Path(output_path).with_suffix(f'.frame_{frame_count}.json')
        
        with open(intermediate_file, 'w') as f:
            json.dump(results, f, indent=2)
    
    def _save_results(self, results: Dict, output_path: str):
        """Сохранение финальных результатов"""
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2)

def main():
    parser = argparse.ArgumentParser(description='SLAM Processor for Drone Videos')
    parser.add_argument('--video', type=str, required=True, help='Path to input video')
    parser.add_argument('--output', type=str, required=True, help='Path to output JSON')
    parser.add_argument('--dataset', type=str, choices=['euroc', 'tum', 'custom'], 
                       default='custom', help='Dataset type')
    
    args = parser.parse_args()
    
    processor = SlamProcessor(args.dataset)
    results = processor.process_video(args.video, args.output)
    
    print(f"Обработка завершена!")
    print(f"Обработано кадров: {results['processed_frames']}")
    print(f"Точек в облаке: {len(results['point_cloud'])}")
    print(f"Поз в траектории: {len(results['trajectory'])}")

if __name__ == "__main__":
    main()