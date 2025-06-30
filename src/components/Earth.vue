<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';

// 定义地点信息接口
interface LocationInfo {
  name: string;
  latitude: number;
  longitude: number;
  population?: number;
  additionalInfo?: string;
}

// 组件属性
const props = defineProps<{
  showLocations?: boolean;
}>();

// 响应式状态
const container = ref<HTMLElement | null>(null);
const tooltipEl = ref<HTMLElement | null>(null);
const tooltipVisible = ref(false);
const tooltipContent = ref('');
const tooltipPosition = ref({ x: 0, y: 0 });
const showLocations = ref(props.showLocations || false);

// 场景相关变量
let scene: THREE.Scene;
let camera: THREE.PerspectiveCamera;
let renderer: THREE.WebGLRenderer;
let earth: THREE.Mesh;
let controls: OrbitControls;
let raycaster: THREE.Raycaster;
let mouse: THREE.Vector2;
let locationMarkers: THREE.Group;
let animationFrameId: number;

// 地点数据
const locations = ref<LocationInfo[]>([
  { name: '北京', latitude: 39.9042, longitude: 116.4074, population: 21.54, additionalInfo: '中国首都' },
  { name: '纽约', latitude: 40.7128, longitude: -74.0060, population: 8.38, additionalInfo: '美国最大城市' },
  { name: '东京', latitude: 35.6762, longitude: 139.6503, population: 13.96, additionalInfo: '日本首都' },
  { name: '伦敦', latitude: 51.5074, longitude: -0.1278, population: 8.98, additionalInfo: '英国首都' },
  { name: '悉尼', latitude: -33.8688, longitude: 151.2093, population: 5.23, additionalInfo: '澳大利亚最大城市' },
]);

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
  
  // 加载纹理
  const earthTexture = textureLoader.load('/textures/earth_daymap.jpg');
  const bumpMap = textureLoader.load('/textures/earth_bumpmap.jpg');
  const specularMap = textureLoader.load('/textures/earth_specular.jpg');
  const cloudsTexture = textureLoader.load('/textures/earth_clouds.png');
  
  // 添加错误处理
  textureLoader.manager.onError = function(url) {
    console.error('加载纹理失败:', url);
  };
  
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
  scene.add(earth);
  
  // 创建云层
  const cloudsGeometry = new THREE.SphereGeometry(2.01, 64, 64);
  const cloudsMaterial = new THREE.MeshPhongMaterial({
    map: cloudsTexture,
    transparent: true,
    opacity: 0.4,
  });
  
  const clouds = new THREE.Mesh(cloudsGeometry, cloudsMaterial);
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
  const theta = (longitude + 180) * (Math.PI / 180);
  
  const x = -radius * Math.sin(phi) * Math.cos(theta);
  const y = radius * Math.cos(phi);
  const z = radius * Math.sin(phi) * Math.sin(theta);
  
  return new THREE.Vector3(x, y, z);
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
      // 隐藏工具提示
      tooltipVisible.value = false;
    }
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
    // 更新现有地点
    locations.value[index] = { ...locations.value[index], ...location };
  } else {
    // 添加新地点
    locations.value.push(location);
  }
  
  // 重新创建标记
  if (showLocations.value && locationMarkers) {
    createLocationMarkers();
  }
};

// 删除地点
const removeLocation = (locationName: string) => {
  const index = locations.value.findIndex(loc => loc.name === locationName);
  
  if (index !== -1) {
    locations.value.splice(index, 1);
    
    // 重新创建标记
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

// 监听showLocations属性变化
watch(() => props.showLocations, (newVal) => {
  if (newVal !== undefined) {
    toggleLocations(newVal);
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
});

// 暴露方法和属性
defineExpose({
  addOrUpdateLocation,
  removeLocation,
  toggleLocations,
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
  background-color: rgba(0, 0, 0, 0.7);
  color: white;
  padding: 8px 12px;
  border-radius: 4px;
  font-size: 14px;
  pointer-events: none;
  z-index: 1000;
  max-width: 200px;
}
</style>