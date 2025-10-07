import numpy as np
import cv2
import json
from pathlib import Path
from typing import List, Tuple, Optional
import time

class FeatureMatcher:
    def __init__(self):
        self.orb = cv2.ORB_create(nfeatures=2000, scaleFactor=1.2, nlevels=8)
        self.bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
        self.last_keypoints = None
        self.last_descriptors = None
        self.last_frame = None
        
    def extract_features(self, image: np.ndarray) -> Tuple[List[cv2.KeyPoint], np.ndarray]:
        """Извлечение ORB особенностей"""
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        keypoints, descriptors = self.orb.detectAndCompute(gray, None)
        return keypoints, descriptors
    
    def match_features(self, kp1: List[cv2.KeyPoint], desc1: np.ndarray, 
                      kp2: List[cv2.KeyPoint], desc2: np.ndarray) -> List[cv2.DMatch]:
        """Сопоставление особенностей между кадрами"""
        if desc1 is None or desc2 is None:
            return []
            
        matches = self.bf.match(desc1, desc2)
        matches = sorted(matches, key=lambda x: x.distance)
        return matches[:100]  # Ограничиваем количество матчей

class PoseEstimator:
    def __init__(self, camera_matrix: np.ndarray, dist_coeffs: np.ndarray = None):
        self.camera_matrix = camera_matrix
        self.dist_coeffs = dist_coeffs if dist_coeffs is not None else np.zeros(5)
        
    def estimate_pose(self, points1: np.ndarray, points2: np.ndarray) -> Tuple[np.ndarray, np.ndarray, bool]:
        """Оценка позы камеры используя Essential Matrix"""
        if len(points1) < 8:
            return np.eye(3), np.zeros(3), False
            
        # Вычисление Essential Matrix
        E, mask = cv2.findEssentialMat(points1, points2, self.camera_matrix, 
                                      method=cv2.RANSAC, prob=0.999, threshold=1.0)
        
        if E is None or E.shape != (3, 3):
            return np.eye(3), np.zeros(3), False
            
        # Восстановление позы из Essential Matrix
        points, R, t, mask = cv2.recoverPose(E, points1, points2, self.camera_matrix)
        
        return R, t[:, 0], True

class BundleAdjustment:
    def __init__(self):
        self.points_3d = []  # 3D точки в мире
        self.camera_poses = []  # Позы камеры
        
    def add_frame(self, R: np.ndarray, t: np.ndarray, points: np.ndarray):
        """Добавление нового кадра и точек"""
        # Преобразование в однородные координаты
        pose = np.eye(4)
        pose[:3, :3] = R
        pose[:3, 3] = t
        
        self.camera_poses.append(pose)
        
        # Триангуляция новых 3D точек
        new_points = self._triangulate_points(pose, points)
        self.points_3d.extend(new_points)
        
    def _triangulate_points(self, pose: np.ndarray, points: np.ndarray) -> List[np.ndarray]:
        """Триангуляция 3D точек из 2D соответствий"""
        # Упрощенная триангуляция - в реальности нужны два кадра
        points_3d = []
        for point in points:
            # Преобразование в нормализованные координаты камеры
            point_3d = np.array([point[0], point[1], 1.0])
            # Преобразование в мировые координаты
            point_world = pose @ np.append(point_3d, 1.0)
            points_3d.append(point_world[:3])
            
        return points_3d

class MonoSLAM:
    def __init__(self, camera_width: int = 752, camera_height: int = 480):
        self.feature_matcher = FeatureMatcher()
        self.bundle_adjustment = BundleAdjustment()
        
        # Параметры камеры по умолчанию (можно загрузить из калибровки)
        self.camera_matrix = np.array([
            [458.654, 0, 367.215],
            [0, 457.296, 248.375],
            [0, 0, 1]
        ])
        
        self.pose_estimator = PoseEstimator(self.camera_matrix)
        
        self.trajectory = []
        self.point_cloud = []
        self.current_pose = np.eye(4)
        
    def process_frame(self, frame: np.ndarray, frame_id: int) -> dict:
        """Обработка одного кадра SLAM"""
        start_time = time.time()
        
        # Извлечение особенностей
        keypoints, descriptors = self.feature_matcher.extract_features(frame)
        
        if self.feature_matcher.last_frame is not None:
            # Сопоставление с предыдущим кадром
            matches = self.feature_matcher.match_features(
                self.feature_matcher.last_keypoints, self.feature_matcher.last_descriptors,
                keypoints, descriptors
            )
            
            if len(matches) > 8:
                # Подготовка точек для оценки позы
                points1 = np.float32([self.feature_matcher.last_keypoints[m.queryIdx].pt for m in matches])
                points2 = np.float32([keypoints[m.trainIdx].pt for m in matches])
                
                # Оценка позы камеры
                R, t, success = self.pose_estimator.estimate_pose(points1, points2)
                
                if success:
                    # Обновление текущей позы
                    delta_pose = np.eye(4)
                    delta_pose[:3, :3] = R
                    delta_pose[:3, 3] = t
                    self.current_pose = self.current_pose @ delta_pose
                    
                    # Добавление в bundle adjustment
                    self.bundle_adjustment.add_frame(R, t, points2)
                    
                    # Обновление облака точек
                    self._update_point_cloud(keypoints, descriptors, matches)
        
        # Сохранение текущего кадра для следующей итерации
        self.feature_matcher.last_keypoints = keypoints
        self.feature_matcher.last_descriptors = descriptors
        self.feature_matcher.last_frame = frame.copy()
        
        # Сохранение траектории
        self._update_trajectory(frame_id)
        
        processing_time = time.time() - start_time
        
        return {
            'pose': self._get_current_pose_dict(frame_id),
            'points': self._get_current_points_dict(),
            'processing_time': processing_time,
            'features_count': len(keypoints)
        }
    
    def _update_trajectory(self, frame_id: int):
        """Обновление траектории камеры"""
        position = self.current_pose[:3, 3]
        rotation = self.current_pose[:3, :3]
        
        # Преобразование матрицы вращения в кватернион
        q = self._rotation_matrix_to_quaternion(rotation)
        
        self.trajectory.append({
            'x': float(position[0]),
            'y': float(position[1]),
            'z': float(position[2]),
            'qx': float(q[0]),
            'qy': float(q[1]),
            'qz': float(q[2]),
            'qw': float(q[3]),
            'frame_id': frame_id,
            'timestamp': frame_id * 0.033
        })
    
    def _update_point_cloud(self, keypoints: List[cv2.KeyPoint], 
                          descriptors: np.ndarray, matches: List[cv2.DMatch]):
        """Обновление облака точек"""
        # Фильтрация новых точек (не совпадающих с существующими)
        new_points_indices = set(range(len(keypoints))) - set([m.trainIdx for m in matches])
        
        for idx in list(new_points_indices)[:50]:  # Ограничиваем количество новых точек
            kp = keypoints[idx]
            point_3d = self._project_to_3d(kp.pt)
            
            if point_3d is not None:
                self.point_cloud.append({
                    'x': float(point_3d[0]),
                    'y': float(point_3d[1]),
                    'z': float(point_3d[2]),
                    'r': 100,
                    'g': 200,
                    'b': 255
                })
    
    def _project_to_3d(self, point_2d: Tuple[float, float]) -> Optional[np.ndarray]:
        """Проекция 2D точки в 3D пространство (упрощенная)"""
        # В реальном SLAM здесь используется триангуляция между несколькими кадрами
        # и оптимизация через bundle adjustment
        
        # Упрощенная проекция - предполагаем фиксированную глубину
        depth = 5.0  # метры
        point_normalized = np.linalg.inv(self.camera_matrix) @ np.array([point_2d[0], point_2d[1], 1.0])
        point_3d_camera = point_normalized * depth
        point_3d_world = self.current_pose @ np.append(point_3d_camera, 1.0)
        
        return point_3d_world[:3]
    
    def _rotation_matrix_to_quaternion(self, R: np.ndarray) -> np.ndarray:
        """Преобразование матрицы вращения в кватернион"""
        # Упрощенное преобразование
        # В реальности нужно использовать правильную математику
        return np.array([0.0, 0.0, 0.0, 1.0])  # Заглушка
    
    def _get_current_pose_dict(self, frame_id: int) -> dict:
        """Получение текущей позы в виде словаря"""
        if not self.trajectory:
            return {
                'x': 0.0, 'y': 0.0, 'z': 0.0,
                'qx': 0.0, 'qy': 0.0, 'qz': 0.0, 'qw': 1.0,
                'frame_id': frame_id,
                'timestamp': frame_id * 0.033
            }
        return self.trajectory[-1]
    
    def _get_current_points_dict(self) -> List[dict]:
        """Получение текущего облака точек"""
        return self.point_cloud[-100:] if self.point_cloud else []

class SLAMProcessor:
    def __init__(self, dataset_type: str = "euroc"):
        self.slam = MonoSLAM()
        self.processed_frames = 0
        
    def process_video(self, video_path: str, output_path: str = None) -> dict:
        """Обработка видео через реальный SLAM"""
        cap = cv2.VideoCapture(video_path)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        results = {
            'trajectory': [],
            'point_cloud': [],
            'processed_frames': 0,
            'total_frames': total_frames,
            'processing_times': []
        }
        
        frame_count = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            # Пропускаем каждый второй кадр для производительности
            if frame_count % 2 == 0:
                frame_count += 1
                continue
                
            # Обработка кадра через SLAM
            slam_result = self.slam.process_frame(frame, frame_count)
            
            if slam_result:
                results['trajectory'] = self.slam.trajectory
                results['point_cloud'] = self.slam.point_cloud
                results['processed_frames'] = frame_count
                results['processing_times'].append(slam_result['processing_time'])
                
            frame_count += 1
            
            # Сохранение прогресса каждые 50 кадров
            if frame_count % 50 == 0 and output_path:
                self._save_intermediate_results(results, output_path, frame_count)
                print(f"Обработано кадров: {frame_count}/{total_frames}")
                
            # Ограничиваем обработку для демонстрации
            if frame_count > 300:
                break
                
        cap.release()
        
        # Финальное сохранение
        if output_path:
            self._save_results(results, output_path)
            
        # Статистика обработки
        if results['processing_times']:
            avg_time = np.mean(results['processing_times'])
            print(f"Среднее время обработки кадра: {avg_time:.3f} сек")
            
        return results
    
    def process_live_stream(self, stream_url: str, duration: int = 30) -> dict:
        """Обработка живого видеопотока с дрона"""
        # Реализация обработки живого потока
        pass
    
    def _save_intermediate_results(self, results: dict, output_path: str, frame_count: int):
        """Сохранение промежуточных результатов"""
        intermediate_file = Path(output_path).with_suffix(f'.frame_{frame_count}.json')
        with open(intermediate_file, 'w') as f:
            json.dump(results, f, indent=2, default=self._json_serializer)
    
    def _save_results(self, results: dict, output_path: str):
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
        return str(obj)

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Real MonoSLAM Processor')
    parser.add_argument('--video', type=str, required=True, help='Path to input video')
    parser.add_argument('--output', type=str, required=True, help='Path to output JSON')
    parser.add_argument('--dataset', type=str, choices=['euroc', 'tum', 'custom'], 
                       default='custom', help='Dataset type')
    
    args = parser.parse_args()
    
    processor = SLAMProcessor(args.dataset)
    results = processor.process_video(args.video, args.output)
    
    print(f"\nОбработка завершена!")
    print(f"Обработано кадров: {results['processed_frames']}")
    print(f"Точек в облаке: {len(results['point_cloud'])}")
    print(f"Поз в траектории: {len(results['trajectory'])}")

if __name__ == "__main__":
    main()