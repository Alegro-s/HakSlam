import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class ConfigService {
  static Future<Map<String, dynamic>> loadConfig(String dataset) async {
    try {
      final configPath = 'config/${dataset}_config.yaml';
      final yamlString = await rootBundle.loadString(configPath);
      final config = loadYaml(yamlString);
      return _convertYamlToMap(config);
    } catch (e) {
      print('Error loading config: $e');
      return _getDefaultConfig();
    }
  }

  static dynamic _convertYamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.nodes.forEach((key, value) {
        map[key.toString()] = _convertYamlToMap(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map((e) => _convertYamlToMap(e)).toList();
    } else {
      return yaml;
    }
  }

  static Map<String, dynamic> _getDefaultConfig() {
    return {
      'Camera': {
        'width': 752,
        'height': 480,
        'fps': 20.0,
      },
      'ORB': {
        'nFeatures': 1000,
        'scaleFactor': 1.2,
      }
    };
  }

  // Метод для получения специфичных параметров камеры
  static Future<Map<String, dynamic>> getCameraParams(String dataset) async {
    final config = await loadConfig(dataset);
    if (config['Camera'] is Map<String, dynamic>) {
      return config['Camera'] as Map<String, dynamic>;
    }
    return {};
  }

  // Метод для получения ORB параметров
  static Future<Map<String, dynamic>> getORBParams(String dataset) async {
    final config = await loadConfig(dataset);
    if (config['ORB'] is Map<String, dynamic>) {
      return config['ORB'] as Map<String, dynamic>;
    }
    return {};
  }
}