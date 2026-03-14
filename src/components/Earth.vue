<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
import worldGeoJSON from '../assets/world.json';
import locationsData from '../assets/locations.json';

// 定义地点信息接口
interface LocationInfo {
  name: string;
  latitude: number;
  longitude: number;
  population?: number;
  additionalInfo?: string;
}

// 国家信息接口
interface CountryInfo {
  name: string;
  iso_a2: string;
  iso_a3: string;
  iso_n3: string;
}

// GeoJSON类型定义
interface GeoJSONFeature {
  type: string;
  properties: {
    name: string;
    iso_a2: string;
    iso_a3: string;
    iso_n3: string;
  };
  geometry: {
    type: string;
    coordinates: number[][][] | number[][][][];
  };
}

interface GeoJSON {
  type: string;
  features: GeoJSONFeature[];
}

// 组件属性
const props = defineProps<{
  showLocations?: boolean;
  showCountries?: boolean;
}>();

// 响应式状态
const container = ref<HTMLElement | null>(null);
const tooltipEl = ref<HTMLElement | null>(null);
const tooltipVisible = ref(false);
const tooltipContent = ref('');
const tooltipPosition = ref({ x: 0, y: 0 });
const showLocations = ref(props.showLocations || false);
const showCountries = ref(props.showCountries || false);

// 场景相关变量
let scene: THREE.Scene;
let camera: THREE.PerspectiveCamera;
let renderer: THREE.WebGLRenderer;
let earth: THREE.Mesh;
let controls: OrbitControls;
let raycaster: THREE.Raycaster;
let mouse: THREE.Vector2;
let locationMarkers: THREE.Group;
let countryMeshes: THREE.Mesh[] = [];
let hoveredCountry: THREE.Mesh | null = null;
let animationFrameId: number;

// 地点数据 - 从JSON文件加载
const locations = ref<LocationInfo[]>(locationsData as LocationInfo[]);

// 初始化Three.js场景
const initThree = () => {
  if (!container.value) return;
  
  // 创建场景
  scene = new THREE.Scene();
  
  // 创建相机
  const width = container.value.clientWidth;
  const height = container.value.clientHeight;
  camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
  camera.position.z = 5;
  
  // 创建渲染器
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setSize(width, height);
  renderer.setPixelRatio(window.devicePixelRatio);
  container.value.appendChild(renderer.domElement);
  
  // 创建光照
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
  scene.add(ambientLight);
  
  const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
  directionalLight.position.set(5, 3, 5);
  scene.add(directionalLight);
  
  // 创建地球
  createEarth();
  
  // 创建地点标记
  locationMarkers = new THREE.Group();
  scene.add(locationMarkers);
  if (showLocations.value) {
    createLocationMarkers();
  }
  
  // 创建国家边界
  if (showCountries.value) {
    createCountries();
  }
  
  // 添加轨道控制
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.rotateSpeed = 0.5;
  controls.minDistance = 3;
  controls.maxDistance = 10;
  
  // 初始化射线和鼠标位置
  raycaster = new THREE.Raycaster();
  mouse = new THREE.Vector2();
  
  // 添加事件监听
  window.addEventListener('resize', onWindowResize);
  renderer.domElement.addEventListener('mousemove', onMouseMove);
  
  // 开始动画循环
  animate();
};

// 创建地球
const createEarth = () => {
  const textureLoader = new THREE.TextureLoader();
  const texturePath = '/textures/';
  
  // 加载纹理
  const earthTexture = textureLoader.load(texturePath + 'earth_daymap.jpg');
  const bumpMap = textureLoader.load(texturePath + 'earth_bumpmap.jpg');
  const specularMap = textureLoader.load(texturePath + 'earth_specular.jpg');
  const cloudsTexture = textureLoader.load(texturePath + 'earth_clouds.png');
  
  // 加载完成后设置各向异性
  const maxAnisotropy = renderer.capabilities.getMaxAnisotropy();
  earthTexture.anisotropy = maxAnisotropy;
  bumpMap.anisotropy = maxAnisotropy;
  specularMap.anisotropy = maxAnisotropy;
  cloudsTexture.anisotropy = maxAnisotropy;
  
  // 创建地球几何体和材质
  const earthGeometry = new THREE.SphereGeometry(2, 64, 64);
  const earthMaterial = new THREE.MeshPhongMaterial({
    map: earthTexture,
    bumpMap: bumpMap,
    bumpScale: 0.05,
    specularMap: specularMap,
    specular: new THREE.Color(0x333333),
    shininess: 5,
  });
  
  // 创建地球网格
  earth = new THREE.Mesh(earthGeometry, earthMaterial);
  earth.renderOrder = 0;
  scene.add(earth);
  
  // 创建云层
  const cloudsGeometry = new THREE.SphereGeometry(2.01, 64, 64);
  const cloudsMaterial = new THREE.MeshPhongMaterial({
    map: cloudsTexture,
    transparent: true,
    opacity: 0.4,
    depthWrite: false
  });
  
  const clouds = new THREE.Mesh(cloudsGeometry, cloudsMaterial);
  clouds.renderOrder = 1;
  scene.add(clouds);
  
  // 添加星空背景
  const starsGeometry = new THREE.BufferGeometry();
  const starsCount = 1000;
  const positions = new Float32Array(starsCount * 3);
  
  for (let i = 0; i < starsCount * 3; i += 3) {
    positions[i] = (Math.random() - 0.5) * 100;
    positions[i + 1] = (Math.random() - 0.5) * 100;
    positions[i + 2] = (Math.random() - 0.5) * 100;
  }
  
  starsGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  
  const starsMaterial = new THREE.PointsMaterial({
    color: 0xffffff,
    size: 0.1,
  });
  
  const stars = new THREE.Points(starsGeometry, starsMaterial);
  scene.add(stars);
};

// 创建地点标记
const createLocationMarkers = () => {
  // 清除现有标记
  while (locationMarkers.children.length > 0) {
    locationMarkers.remove(locationMarkers.children[0]);
  }
  
  // 为每个地点创建标记
  locations.value.forEach(location => {
    const { latitude, longitude } = location;
    
    // 将经纬度转换为3D坐标
    const position = latLongToVector3(latitude, longitude, 2.05);
    
    // 创建标记几何体和材质
    const markerGeometry = new THREE.SphereGeometry(0.03, 16, 16);
    const markerMaterial = new THREE.MeshBasicMaterial({ color: 0xff0000 });
    const marker = new THREE.Mesh(markerGeometry, markerMaterial);
    
    // 设置标记位置
    marker.position.set(position.x, position.y, position.z);
    marker.userData = location;
    
    // 添加到标记组
    locationMarkers.add(marker);
  });
};

// 将经纬度转换为3D向量
const latLongToVector3 = (latitude: number, longitude: number, radius: number): THREE.Vector3 => {
  const phi = (90 - latitude) * (Math.PI / 180);
  const theta = -longitude * (Math.PI / 180);
  
  const x = radius * Math.sin(phi) * Math.cos(theta);
  const y = radius * Math.cos(phi);
  const z = radius * Math.sin(phi) * Math.sin(theta);
  
  return new THREE.Vector3(x, y, z);
};

// 将3D坐标转换为经纬度
const vector3ToLatLong = (point: THREE.Vector3): { latitude: number; longitude: number } => {
  const radius = Math.sqrt(point.x * point.x + point.y * point.y + point.z * point.z);
  const latitude = 90 - Math.acos(point.y / radius) * (180 / Math.PI);
  const longitude = -Math.atan2(point.z, point.x) * (180 / Math.PI);
  return { latitude, longitude };
};

// 判断点是否在经纬度多边形内部
const isPointInPolygon = (lat: number, lon: number, polygon: number[][]): boolean => {
  let inside = false;
  
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [lon1, lat1] = polygon[j];
    const [lon2, lat2] = polygon[i];
    
    const intersect = ((lat1 > lat) !== (lat2 > lat)) &&
      (lon < (lon2 - lon1) * (lat - lat1) / (lat2 - lat1) + lon1);
    
    if (intersect) inside = !inside;
  }
  
  return inside;
};

// 查找国家
const findCountry = (latitude: number, longitude: number): CountryInfo | null => {
  const geoJSON = worldGeoJSON as GeoJSON;
  
  for (const feature of geoJSON.features) {
    const { name, iso_a2, iso_a3, iso_n3 } = feature.properties;
    const geometry = feature.geometry;
    
    const coordinates = geometry.type === 'Polygon' 
      ? [geometry.coordinates as number[][][]]
      : geometry.coordinates as number[][][][];
    
    for (const polygon of coordinates) {
      if (!polygon || polygon.length === 0) continue;
      
      const exterior = polygon[0];
      if (!exterior || exterior.length < 3) continue;
      
      if (isPointInPolygon(latitude, longitude, exterior)) {
        return { name, iso_a2, iso_a3, iso_n3 };
      }
    }
  }
  
  return null;
};

// 创建球面三角形网格
const createSphericalTriangles = (
  vertices: THREE.Vector3[],
  indices: number[],
  radius: number
): THREE.BufferGeometry => {
  const geometry = new THREE.BufferGeometry();
  
  // 投影到球面
  const sphericalVertices = vertices.map(v => {
    const length = v.length();
    return new THREE.Vector3(
      (v.x / length) * radius,
      (v.y / length) * radius,
      (v.z / length) * radius
    );
  });
  
  geometry.setFromPoints(sphericalVertices);
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  
  return geometry;
};

// 三角剖分简单实现（适用于凸多边形）
const triangulatePolygon = (points: THREE.Vector3[]): number[] => {
  const indices: number[] = [];
  
  if (points.length < 3) return indices;
  
  // 简单扇形三角剖分
  for (let i = 1; i < points.length - 1; i++) {
    indices.push(0, i, i + 1);
  }
  
  return indices;
};

// 创建国家边界和交互网格
const createCountries = () => {
  console.log('createCountries executing...');
  // 清除现有的国家组
  const existingGroup = scene.getObjectByName('countryGroup');
  if (existingGroup) {
    scene.remove(existingGroup);
  }
  
  countryMeshes.forEach(mesh => {
    mesh.geometry.dispose();
    (mesh.material as THREE.Material).dispose();
  });
  countryMeshes = [];
  
  const geoJSON = worldGeoJSON as GeoJSON;
  const LINE_RADIUS = 2.02;
  const MESH_RADIUS = 2.015;
  
  const countryGroup = new THREE.Group();
  countryGroup.name = 'countryGroup';
  
  // 遍历所有国家
  geoJSON.features.forEach((feature) => {
    const { name, iso_a2, iso_a3, iso_n3 } = feature.properties;
    const geometry = feature.geometry;
    
    const coordinates = geometry.type === 'Polygon' 
      ? [geometry.coordinates as number[][][]]
      : geometry.coordinates as number[][][][];
    
    coordinates.forEach((polygon) => {
      if (!polygon || polygon.length === 0) return;
      
      const exterior = polygon[0];
      if (!exterior || exterior.length < 3) return;
      
      // 创建边界线
      const lineVertices: THREE.Vector3[] = exterior.map(coord => {
        const [lon, lat] = coord;
        return latLongToVector3(lat, lon, LINE_RADIUS);
      });
      lineVertices.push(lineVertices[0].clone());
      
      const lineGeometry = new THREE.BufferGeometry().setFromPoints(lineVertices);
      const lineMaterial = new THREE.LineBasicMaterial({ 
        color: 0x00ffff, 
        opacity: 0.9
      });
      const line = new THREE.Line(lineGeometry, lineMaterial);
      countryGroup.add(line);
      
      // 创建填充网格
      if (exterior.length >= 3) {
        const fillVertices: THREE.Vector3[] = exterior.map(coord => {
          const [lon, lat] = coord;
          return latLongToVector3(lat, lon, MESH_RADIUS);
        });
        
        const fillIndices: number[] = [];
        for (let i = 1; i < fillVertices.length - 1; i++) {
          fillIndices.push(0, i, i + 1);
        }
        
        const fillGeometry = new THREE.BufferGeometry().setFromPoints(fillVertices);
        fillGeometry.setIndex(fillIndices);
        fillGeometry.computeVertexNormals();
        
        const fillMaterial = new THREE.MeshBasicMaterial({
          color: 0x0088ff,
          transparent: true,
          opacity: 0.2,
          side: THREE.DoubleSide,
          depthWrite: false
        });
        
        const fillMesh = new THREE.Mesh(fillGeometry, fillMaterial);
        fillMesh.userData = { 
          country: { name, iso_a2, iso_a3, iso_n3 },
          isCountry: true 
        };
        
        countryMeshes.push(fillMesh);
        countryGroup.add(fillMesh);
      }
    });
  });
  
  scene.add(countryGroup);
};

// 处理窗口大小变化
const onWindowResize = () => {
  if (!container.value || !camera || !renderer) return;
  
  const width = container.value.clientWidth;
  const height = container.value.clientHeight;
  
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  
  renderer.setSize(width, height);
};

// 处理鼠标移动
const onMouseMove = (event: MouseEvent) => {
  if (!container.value || !camera || !renderer || !raycaster || !scene || !tooltipEl.value) return;
  
  // 计算鼠标位置
  const rect = renderer.domElement.getBoundingClientRect();
  mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
  
  // 设置射线
  raycaster.setFromCamera(mouse, camera);
  
  // 检测国家交叉（优先）
  if (showCountries.value && countryMeshes.length > 0) {
    // 先检测是否悬停在某个国家上
    const intersects = raycaster.intersectObjects(countryMeshes, false);
    
    if (intersects.length > 0) {
      const mesh = intersects[0].object as THREE.Mesh;
      const userData = mesh.userData as { country: CountryInfo };
      const country = userData.country;
      
      // 高亮效果
      if (hoveredCountry !== mesh) {
        // 恢复上一个
        if (hoveredCountry) {
          (hoveredCountry.material as THREE.MeshBasicMaterial).opacity = 0.15;
        }
        // 高亮新的
        hoveredCountry = mesh;
        (hoveredCountry.material as THREE.MeshBasicMaterial).opacity = 0.4;
      }
      
      // 更新工具提示内容
      tooltipContent.value = `
        <strong>${country.name}</strong><br>
        ISO A2: ${country.iso_a2}<br>
        ISO A3: ${country.iso_a3}
      `;
      
      // 更新工具提示位置
      tooltipPosition.value = {
        x: event.clientX,
        y: event.clientY
      };
      
      // 显示工具提示
      tooltipVisible.value = true;
      return;
    } else {
      // 清除高亮
      if (hoveredCountry) {
        (hoveredCountry.material as THREE.MeshBasicMaterial).opacity = 0.15;
        hoveredCountry = null;
      }
    }
  }
  
  // 检测与地点标记的交叉
  if (showLocations.value && locationMarkers) {
    const intersects = raycaster.intersectObjects(locationMarkers.children, true);
    
    if (intersects.length > 0) {
      const location = intersects[0].object.userData as LocationInfo;
      
      // 更新工具提示内容
      tooltipContent.value = `
        <strong>${location.name}</strong><br>
        经度: ${location.longitude.toFixed(2)}°<br>
        纬度: ${location.latitude.toFixed(2)}°<br>
        ${location.population ? `人口: ${location.population} 百万<br>` : ''}
        ${location.additionalInfo ? location.additionalInfo : ''}
      `;
      
      // 更新工具提示位置
      tooltipPosition.value = {
        x: event.clientX,
        y: event.clientY
      };
      
      // 显示工具提示
      tooltipVisible.value = true;
    } else {
      tooltipVisible.value = false;
    }
  } else {
    tooltipVisible.value = false;
  }
};

// 动画循环
const animate = () => {
  animationFrameId = requestAnimationFrame(animate);
  
  if (controls) {
    controls.update();
  }
  
  if (renderer && scene && camera) {
    renderer.render(scene, camera);
  }
};

// 添加或更新地点
const addOrUpdateLocation = (location: LocationInfo) => {
  const index = locations.value.findIndex(loc => 
    loc.name === location.name && 
    loc.latitude === location.latitude && 
    loc.longitude === location.longitude
  );
  
  if (index !== -1) {
    locations.value[index] = { ...locations.value[index], ...location };
  } else {
    locations.value.push(location);
  }
  
  if (showLocations.value && locationMarkers) {
    createLocationMarkers();
  }
};

// 删除地点
const removeLocation = (locationName: string) => {
  const index = locations.value.findIndex(loc => loc.name === locationName);
  
  if (index !== -1) {
    locations.value.splice(index, 1);
    
    if (showLocations.value && locationMarkers) {
      createLocationMarkers();
    }
  }
};

// 切换地点显示
const toggleLocations = (show?: boolean) => {
  showLocations.value = show !== undefined ? show : !showLocations.value;
  
  if (showLocations.value && locationMarkers) {
    createLocationMarkers();
  } else if (locationMarkers) {
    while (locationMarkers.children.length > 0) {
      locationMarkers.remove(locationMarkers.children[0]);
    }
  }
};

// 切换国家显示
const toggleCountries = (show?: boolean) => {
  console.log('toggleCountries called, show:', show);
  showCountries.value = show !== undefined ? show : !showCountries.value;
  console.log('showCountries.value:', showCountries.value);
  
  if (showCountries.value) {
    createCountries();
  } else {
    // 清除旧的
    countryMeshes.forEach(mesh => {
      mesh.geometry.dispose();
      (mesh.material as THREE.Material).dispose();
    });
    
    // 移除国家组
    const countryGroup = scene.getObjectByName('countryGroup');
    if (countryGroup) {
      scene.remove(countryGroup);
    }
    
    countryMeshes = [];
    hoveredCountry = null;
  }
};

// 监听属性变化
watch(() => props.showLocations, (newVal) => {
  if (newVal !== undefined) {
    toggleLocations(newVal);
  }
});

watch(() => props.showCountries, (newVal) => {
  if (newVal !== undefined) {
    toggleCountries(newVal);
  }
});

// 组件挂载时初始化
onMounted(() => {
  initThree();
});

// 组件卸载时清理
onUnmounted(() => {
  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId);
  }
  
  if (renderer && renderer.domElement && container.value) {
    container.value.removeChild(renderer.domElement);
  }
  
  window.removeEventListener('resize', onWindowResize);
  if (renderer) {
    renderer.domElement.removeEventListener('mousemove', onMouseMove);
  }
  
  // 清理国家网格
  countryMeshes.forEach(mesh => {
    mesh.geometry.dispose();
    (mesh.material as THREE.Material).dispose();
  });
});

// 暴露方法和属性
defineExpose({
  addOrUpdateLocation,
  removeLocation,
  toggleLocations,
  toggleCountries,
  locations
});
</script>

<template>
  <div class="earth-container" ref="container">
    <!-- 工具提示 -->
    <div 
      ref="tooltipEl"
      class="tooltip" 
      v-show="tooltipVisible" 
      :style="{
        left: `${tooltipPosition.x + 10}px`,
        top: `${tooltipPosition.y + 10}px`
      }"
      v-html="tooltipContent"
    ></div>
  </div>
</template>

<style scoped>
.earth-container {
  width: 100%;
  height: 100%;
  position: relative;
  overflow: hidden;
}

.tooltip {
  position: fixed;
  background-color: rgba(0, 0, 0, 0.8);
  color: white;
  padding: 10px 14px;
  border-radius: 6px;
  font-size: 14px;
  pointer-events: none;
  z-index: 1000;
  max-width: 220px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}
</style>
