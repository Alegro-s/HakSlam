import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

class VideoPanel extends StatefulWidget {
  final String? videoPath;
  final ValueChanged<String>? onVideoSelected;

  const VideoPanel({super.key, this.videoPath, this.onVideoSelected});

  @override
  State<VideoPanel> createState() => _VideoPanelState();
}

class _VideoPanelState extends State<VideoPanel> {

  final TextEditingController _streamUrlController = TextEditingController();
  String? _currentStreamUrl;

  Future<void> _initNetworkStream(String url) async {
    try {
      await _controller?.dispose();
      _controller = VideoPlayerController.network(url);
      await _controller!.initialize();
      setState(() {
        _currentStreamUrl = url;
        _isPlaying = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть поток: $e')));
    }
  }

  VideoPlayerController? _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant VideoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videoPath == null) return;

    _controller?.dispose();
    
    // Для демонстрации используем заглушку
    // В реальном приложении здесь будет загрузка видео
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        widget.onVideoSelected?.call(result.files.single.path!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выбора видео: $e')),
      );
    }
  }

  void _togglePlayback() {
    if (_controller == null) return;
    
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Заголовок панели
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.videocam, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Видео с камеры",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickVideo,
                  tooltip: "Загрузить видео",
                ),
              ],
            ),
          ),
          
          // Область видео
          Expanded(
            child: Container(
              color: Colors.black,
              child: _buildVideoContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (widget.videoPath == null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _streamUrlController,
              decoration: const InputDecoration(
                hintText: 'RTSP/HTTP stream URL (через прокси) или HLS m3u8',
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Stream URL',
              ),
              onSubmitted: (v) => _initNetworkStream(v),
            ),
            const SizedBox(height:8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    final url = _streamUrlController.text.trim();
                    if (url.isNotEmpty) _initNetworkStream(url);
                  },
                  child: const Text('Открыть поток'),
                ),
                const SizedBox(width:8),
                ElevatedButton(
                  onPressed: _pickVideo,
                  child: const Text('Выбрать файл'),
                ),
                const SizedBox(width:8),
                ElevatedButton(
                  onPressed: () async {
                    // try device camera via a simple intent - note: for full camera support, add camera plugin
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Для доступа к камере добавьте пакет camera и реализуйте поток.')));
                  },
                  child: const Text('Камера устройства'),
                ),
              ],
            ),
            const SizedBox(height:12),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.video_library, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "Выберите датасет или загрузите видео",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Заглушка для видео (в реальном приложении здесь будет VideoPlayer)
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_filled, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(
                "Видео: ${widget.videoPath!.split('/').last}",
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "(Демонстрационный режим)",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        
        // Элементы управления
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.small(
                onPressed: _togglePlayback,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}