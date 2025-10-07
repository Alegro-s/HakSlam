// Минимальная версия Three.js для вашего проекта
// Полную версию скачайте по ссылкам выше

// Заглушка Three.js - в реальном проекте замените на полную версию
console.log('Three.js loaded - using stub version');

// Минимальная реализация для демонстрации
window.THREE = {
  Scene: class Scene {
    constructor() { 
      this.background = null;
      this.children = []; 
    }
    add(obj) { this.children.push(obj); }
    remove(obj) { 
      this.children = this.children.filter(child => child !== obj);
    }
  },
  
  WebGLRenderer: class WebGLRenderer {
    constructor(options) {
      this.domElement = document.createElement('canvas');
      this.setSize(800, 600);
    }
    setSize(w, h) {
      this.domElement.width = w;
      this.domElement.height = h;
    }
    setPixelRatio() {}
    render() {}
  },
  
  PerspectiveCamera: class PerspectiveCamera {
    constructor(fov, aspect, near, far) {
      this.fov = fov;
      this.aspect = aspect;
      this.near = near;
      this.far = far;
      this.position = { x: 0, y: 0, z: 5 };
      this.updateProjectionMatrix = () => {};
      this.lookAt = () => {};
    }
  },
  
  Color: class Color {
    constructor(color) { this.color = color; }
  },
  
  AmbientLight: class AmbientLight {
    constructor(color, intensity) {
      this.color = color;
      this.intensity = intensity;
    }
  },
  
  DirectionalLight: class DirectionalLight {
    constructor(color, intensity) {
      this.color = color;
      this.intensity = intensity;
      this.position = { x: 0, y: 0, z: 0 };
    }
  },
  
  AxesHelper: class AxesHelper {
    constructor(size) { this.size = size; this.visible = true; }
  },
  
  GridHelper: class GridHelper {
    constructor(size, divisions, color1, color2) { 
      this.visible = true; 
    }
  },
  
  Vector3: class Vector3 {
    constructor(x, y, z) {
      this.x = x || 0;
      this.y = y || 0;
      this.z = z || 0;
    }
  },
  
  BufferGeometry: class BufferGeometry {
    constructor() {
      this.attributes = {};
    }
    setFromPoints(points) {
      const positions = new Float32Array(points.length * 3);
      points.forEach((point, i) => {
        positions[i * 3] = point.x;
        positions[i * 3 + 1] = point.y;
        positions[i * 3 + 2] = point.z;
      });
      this.attributes.position = { array: positions, itemSize: 3 };
      return this;
    }
    setAttribute(name, attribute) {
      this.attributes[name] = attribute;
    }
  },
  
  BufferAttribute: class BufferAttribute {
    constructor(array, itemSize) {
      this.array = array;
      this.itemSize = itemSize;
    }
  },
  
  LineBasicMaterial: class LineBasicMaterial {
    constructor(options) {
      this.color = options.color;
      this.linewidth = options.linewidth;
    }
  },
  
  Line: class Line {
    constructor(geometry, material) {
      this.geometry = geometry;
      this.material = material;
      this.visible = true;
    }
  },
  
  SphereGeometry: class SphereGeometry {
    constructor(radius, widthSegments, heightSegments) {
      this.radius = radius;
    }
  },
  
  MeshBasicMaterial: class MeshBasicMaterial {
    constructor(options) {
      this.color = options.color;
    }
  },
  
  Mesh: class Mesh {
    constructor(geometry, material) {
      this.geometry = geometry;
      this.material = material;
      this.position = { x: 0, y: 0, z: 0 };
      this.visible = true;
    }
  },
  
  PointsMaterial: class PointsMaterial {
    constructor(options) {
      this.size = options.size;
      this.vertexColors = options.vertexColors;
      this.sizeAttenuation = options.sizeAttenuation;
    }
  },
  
  Points: class Points {
    constructor(geometry, material) {
      this.geometry = geometry;
      this.material = material;
      this.visible = true;
    }
  }
};

console.log('Three.js stub loaded successfully');