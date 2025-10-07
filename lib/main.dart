import 'package:flutter/material.dart';
import 'package:hakaton/core/services/dataset_service.dart';
import 'package:hakaton/core/services/slam_service.dart';
import 'package:hakaton/core/services/drone_service.dart';
import 'package:hakaton/presentation/pages/page_visualizer.dart';
import 'package:hakaton/presentation/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SlamService()),
        ChangeNotifierProvider(create: (_) => DatasetService()),
        ChangeNotifierProvider(create: (_) => DroneService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SlamVisualizerPage(),
      ),
    );
  }
}