import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hakaton/core/models/slam_data.dart';
import 'package:hakaton/core/services/slam_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';

class VisualizationPanel extends StatefulWidget {
  const VisualizationPanel({super.key});

  @override
  State<VisualizationPanel> createState() => _VisualizationPanelState();
}

class _VisualizationPanelState extends State<VisualizationPanel> {
  WebViewController? _webController;
  bool _isLoading = true;
  bool _isWebViewReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _isWebViewReady = true;
            });
            // Даем время на инициализацию Three.js
            Future.delayed(const Duration(milliseconds: 1000), () {
              _sendInitialData();
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            print('WebView error: ${error.errorCode} - ${error.description}');
          },
        ))
        ..loadHtmlString(_getThreeJsHtml());

    } catch (e) {
      print('WebView initialization error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _getThreeJsHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SLAM 3D Visualizer</title>
  <style>
    body { 
      margin: 0; 
      padding: 0; 
      background: #1a1a1a; 
      overflow: hidden; 
      font-family: Arial, sans-serif;
      width: 100vw;
      height: 100vh;
    }
    #info {
      position: absolute;
      top: 10px;
      left: 10px;
      color: white;
      background: rgba(0,0,0,0.8);
      padding: 10px;
      border-radius: 5px;
      z-index: 100;
      font-size: 12px;
      max-width: 200px;
    }
    #controls {
      position: absolute;
      top: 10px;
      right: 10px;
      background: rgba(0,0,0,0.8);
      padding: 8px;
      border-radius: 5px;
      z-index: 100;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    #loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-size: 16px;
      text-align: center;
      z-index: 1000;
    }
    #error {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: #ff6b6b;
      font-size: 14px;
      text-align: center;
      background: rgba(0,0,0,0.8);
      padding: 20px;
      border-radius: 8px;
      z-index: 1000;
    }
    .control-btn {
      background: #2a2a2a;
      border: none;
      color: white;
      padding: 6px 10px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 11px;
      transition: background 0.2s;
    }
    .control-btn:hover {
      background: #3a3a3a;
    }
    .control-btn.active {
      background: #4a4a4a;
    }
    #canvas-container {
      width: 100%;
      height: 100%;
      display: block;
    }
  </style>
</head>
<body>
  <div id="info">
    <div>SLAM 3D Visualizer</div>
    <div id="stats">Ожидание данных...</div>
  </div>
  
  <div id="controls">
    <button class="control-btn active" onclick="toggleVisibility('trajectory')" id="btn-trajectory">Траектория</button>
    <button class="control-btn active" onclick="toggleVisibility('points')" id="btn-points">Точки</button>
    <button class="control-btn" onclick="toggleVisibility('axes')" id="btn-axes">Оси</button>
    <button class="control-btn" onclick="toggleVisibility('grid')" id="btn-grid">Сетка</button>
    <button class="control-btn" onclick="resetCamera()">Сброс камеры</button>
  </div>

  <div id="loading">
    Загрузка 3D визуализатора...
    <br>
    <div style="margin-top: 10px; font-size: 12px; color: #ccc;">
      Three.js загружается...
    </div>
  </div>

  <div id="error" style="display: none;">
    Ошибка загрузки 3D визуализатора
    <br>
    <button onclick="location.reload()" style="margin-top: 10px; padding: 5px 10px; background: #ff6b6b; border: none; border-radius: 4px; color: white; cursor: pointer;">
      Перезагрузить
    </button>
  </div>

  <div id="canvas-container"></div>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
  <script>
    let scene, camera, renderer;
    let trajectory, pointCloud, currentCamera;
    let axesHelper, gridHelper;
    let isDragging = false;
    let previousMousePosition = { x: 0, y: 0 };
    let cameraDistance = 15;
    let cameraAngleX = Math.PI / 4;
    let cameraAngleY = Math.PI / 4;

    const visibility = {
      trajectory: true,
      points: true,
      axes: false,
      grid: false
    };

    function init() {
      try {
        // Создаем сцену
        scene = new THREE.Scene();
        scene.background = new THREE.Color(0x1a1a1a);
        
        // Создаем камеру
        const container = document.getElementById('canvas-container');
        camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
        updateCameraPosition();
        
        // Создаем рендерер
        renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        renderer.setSize(container.clientWidth, container.clientHeight);
        renderer.setPixelRatio(window.devicePixelRatio);
        container.appendChild(renderer.domElement);
        
        // Освещение
        const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
        scene.add(ambientLight);
        
        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(10, 10, 5);
        scene.add(directionalLight);
        
        // Оси координат
        axesHelper = new THREE.AxesHelper(5);
        axesHelper.visible = visibility.axes;
        scene.add(axesHelper);
        
        // Сетка
        gridHelper = new THREE.GridHelper(20, 20, 0x444444, 0x222222);
        gridHelper.visible = visibility.grid;
        scene.add(gridHelper);

        // Обработчики событий
        setupMouseControls();
        
        // Скрываем loading
        document.getElementById('loading').style.display = 'none';
        
        // Запускаем анимацию
        animate();
        
        console.log('Three.js initialized successfully');
        
      } catch (error) {
        console.error('Three.js initialization error:', error);
        document.getElementById('loading').style.display = 'none';
        document.getElementById('error').style.display = 'block';
      }
    }

    function updateCameraPosition() {
      camera.position.x = cameraDistance * Math.sin(cameraAngleY) * Math.cos(cameraAngleX);
      camera.position.y = cameraDistance * Math.sin(cameraAngleX);
      camera.position.z = cameraDistance * Math.cos(cameraAngleY) * Math.cos(cameraAngleX);
      camera.lookAt(0, 0, 0);
    }

    function setupMouseControls() {
      const canvas = renderer.domElement;
      
      canvas.addEventListener('mousedown', (event) => {
        isDragging = true;
        previousMousePosition = { x: event.clientX, y: event.clientY };
      });
      
      canvas.addEventListener('mousemove', (event) => {
        if (!isDragging) return;
        
        const deltaX = event.clientX - previousMousePosition.x;
        const deltaY = event.clientY - previousMousePosition.y;
        
        cameraAngleY += deltaX * 0.01;
        cameraAngleX += deltaY * 0.01;
        
        cameraAngleX = Math.max(-Math.PI/2 + 0.1, Math.min(Math.PI/2 - 0.1, cameraAngleX));
        
        updateCameraPosition();
        previousMousePosition = { x: event.clientX, y: event.clientY };
      });
      
      canvas.addEventListener('mouseup', () => {
        isDragging = false;
      });
      
      canvas.addEventListener('wheel', (event) => {
        cameraDistance += event.deltaY * 0.01;
        cameraDistance = Math.max(5, Math.min(50, cameraDistance));
        updateCameraPosition();
        event.preventDefault();
      });
    }

    function animate() {
      requestAnimationFrame(animate);
      if (renderer && scene && camera) {
        renderer.render(scene, camera);
      }
    }

    function updateVisualization(data) {
      try {
        console.log('Updating visualization with data:', data);
        
        // Обновляем траекторию
        if (visibility.trajectory && data.poses && data.poses.length > 0) {
          if (trajectory) scene.remove(trajectory);
          
          const trajectoryPoints = [];
          for (let i = 0; i < data.poses.length; i++) {
            const pose = data.poses[i];
            trajectoryPoints.push(new THREE.Vector3(pose.x, pose.y, pose.z));
          }
          
          const trajectoryGeometry = new THREE.BufferGeometry().setFromPoints(trajectoryPoints);
          const trajectoryMaterial = new THREE.LineBasicMaterial({ 
            color: 0x00ff00,
            linewidth: 2 
          });
          
          trajectory = new THREE.Line(trajectoryGeometry, trajectoryMaterial);
          scene.add(trajectory);
          
          // Добавляем текущую позицию камеры
          if (currentCamera) scene.remove(currentCamera);
          
          const lastPose = data.poses[data.poses.length - 1];
          const cameraGeometry = new THREE.SphereGeometry(0.1, 8, 8);
          const cameraMaterial = new THREE.MeshBasicMaterial({ color: 0xff0000 });
          currentCamera = new THREE.Mesh(cameraGeometry, cameraMaterial);
          currentCamera.position.set(lastPose.x, lastPose.y, lastPose.z);
          scene.add(currentCamera);
        }

        // Обновляем облако точек
        if (visibility.points && data.points && data.points.length > 0) {
          if (pointCloud) scene.remove(pointCloud);
          
          const positions = new Float32Array(data.points.length * 3);
          const colors = new Float32Array(data.points.length * 3);
          
          for (let i = 0; i < data.points.length; i++) {
            const point = data.points[i];
            positions[i * 3] = point.x;
            positions[i * 3 + 1] = point.y;
            positions[i * 3 + 2] = point.z;
            colors[i * 3] = point.r / 255;
            colors[i * 3 + 1] = point.g / 255;
            colors[i * 3 + 2] = point.b / 255;
          }
          
          const geometry = new THREE.BufferGeometry();
          geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
          geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
          
          const material = new THREE.PointsMaterial({
            size: 0.05,
            vertexColors: true,
            sizeAttenuation: true
          });
          
          pointCloud = new THREE.Points(geometry, material);
          scene.add(pointCloud);
        }
        
        // Обновляем статистику
        const statsElement = document.getElementById('stats');
        if (statsElement) {
          statsElement.innerHTML = 
            \`Точек: \${data.points?.length || 0}<br>
             Поз: \${data.poses?.length || 0}<br>
             Кадры: \${data.processed_frames || 0}/\${data.total_frames || 0}\`;
        }
      } catch (error) {
        console.error('Error updating visualization:', error);
      }
    }

    function toggleVisibility(element) {
      visibility[element] = !visibility[element];
      
      const button = document.getElementById('btn-' + element);
      if (button) {
        button.classList.toggle('active', visibility[element]);
      }
      
      switch (element) {
        case 'trajectory':
          if (trajectory) trajectory.visible = visibility.trajectory;
          if (currentCamera) currentCamera.visible = visibility.trajectory;
          break;
        case 'points':
          if (pointCloud) pointCloud.visible = visibility.points;
          break;
        case 'axes':
          if (axesHelper) axesHelper.visible = visibility.axes;
          break;
        case 'grid':
          if (gridHelper) gridHelper.visible = visibility.grid;
          break;
      }
    }

    function resetCamera() {
      cameraDistance = 15;
      cameraAngleX = Math.PI / 4;
      cameraAngleY = Math.PI / 4;
      updateCameraPosition();
    }

    function handleResize() {
      const container = document.getElementById('canvas-container');
      if (container && camera && renderer) {
        camera.aspect = container.clientWidth / container.clientHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(container.clientWidth, container.clientHeight);
      }
    }

    // Функция для получения данных из Flutter
    window.onFlutterMessage = function(data) {
      console.log('Received data from Flutter:', data);
      updateVisualization(data);
    };

    // Инициализация при загрузке
    window.addEventListener('DOMContentLoaded', init);
    window.addEventListener('resize', handleResize);

    // Fallback демо данные
    let lastReceived = Date.now();
    setInterval(function() {
      if (Date.now() - lastReceived > 3000) {
        const demo = generateDemoData(Date.now());
        updateVisualization(demo);
        document.getElementById('stats').innerHTML = 'Демо данные<br>(ожидание SLAM)';
      }
    }, 1000);

    function generateDemoData(t) {
      const poses = [];
      for(let i = 0; i < 10; i++) {
        const s = t * 0.001 + i * 0.3;
        poses.push({
          x: Math.sin(s) * 2, 
          y: Math.abs(Math.sin(s * 0.5)) * 0.8 + 0.2, 
          z: Math.cos(s) * 2
        });
      }
      const points = [];
      for(let i = 0; i < 100; i++) {
        points.push({
          x: (Math.random() - 0.5) * 5, 
          y: (Math.random() - 0.5) * 3, 
          z: (Math.random() - 0.5) * 4, 
          r: Math.floor(Math.random() * 255), 
          g: Math.floor(Math.random() * 255), 
          b: Math.floor(Math.random() * 255)
        });
      }
      return {
        poses: poses, 
        points: points, 
        processed_frames: 0, 
        total_frames: 0
      };
    }
  </script>
</body>
</html>
''';
  }

  void _sendSlamDataToWebView(SlamData data) {
    if (_webController == null || !_isWebViewReady) return;

    try {
      final jsonData = {
        'poses': data.trajectory.map((pose) => {
          'x': pose.x,
          'y': pose.y,
          'z': pose.z,
        }).toList(),
        'points': data.pointCloud.map((point) => {
          'x': point.x,
          'y': point.y,
          'z': point.z,
          'r': point.r,
          'g': point.g,
          'b': point.b,
        }).toList(),
        'processed_frames': data.processedFrames,
        'total_frames': data.totalFrames,
      };

      _webController!.runJavaScript(
        'window.onFlutterMessage(${jsonEncode(jsonData)});',
      );
    } catch (error) {
      print('Error sending data to WebView: $error');
    }
  }

  void _sendInitialData() {
    if (_webController == null || !_isWebViewReady) return;

    try {
      final initialData = {
        'poses': [],
        'points': [],
        'processed_frames': 0,
        'total_frames': 0,
      };

      _webController!.runJavaScript(
        'window.onFlutterMessage(${jsonEncode(initialData)});',
      );
    } catch (error) {
      print('Error sending initial data to WebView: $error');
    }
  }

  void _reloadWebView() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isWebViewReady = false;
    });
    _initializeWebView();
  }

  @override
  Widget build(BuildContext context) {
    final slamService = Provider.of<SlamService>(context);
    final slamData = slamService.currentData;

    // Отправляем данные в WebView при их изменении
    if (slamData != null && _isWebViewReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendSlamDataToWebView(slamData);
      });
    }

    return Card(
      child: Column(
        children: [
          // Заголовок панели
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.map, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "3D Визуализация SLAM",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_hasError)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _reloadWebView,
                    tooltip: "Перезагрузить 3D визуализатор",
                  ),
                if (slamData != null) ...[
                  Icon(
                    Icons.circle,
                    color: Colors.greenAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Данные получены",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ] else if (_isWebViewReady) ...[
                  Icon(
                    Icons.circle,
                    color: Colors.blueAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Готов к работе",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueAccent,
                    ),
                  ),
                ] else if (_hasError) ...[
                  Icon(
                    Icons.circle,
                    color: Colors.redAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Ошибка загрузки",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Область 3D визуализации
          Expanded(
            child: _buildWebViewContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebViewContent() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              "Ошибка загрузки 3D визуализатора",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Проверьте подключение к интернету для загрузки Three.js",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Попробовать снова"),
              onPressed: _reloadWebView,
            ),
          ],
        ),
      );
    }

    if (_webController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Инициализация 3D визуализатора...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webController!),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.8),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка 3D визуализатора...',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Загрузка Three.js из интернета',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _webController = null;
    super.dispose();
  }
}