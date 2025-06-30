<script setup lang="ts">
import { ref } from 'vue';
import Earth from './components/Earth.vue';

// 控制是否显示地点标记
const showLocations = ref(false);

// 地球组件引用
const earthRef = ref();

// 切换地点显示
const toggleLocations = () => {
  showLocations.value = !showLocations.value;
};

// 添加新地点
const addLocation = () => {
  if (!earthRef.value) return;
  
  const name = prompt('城市名称:');
  if (!name) return;
  
  const latitude = parseFloat(prompt('纬度 (-90 到 90):', '0') || '0');
  const longitude = parseFloat(prompt('经度 (-180 到 180):', '0') || '0');
  const population = parseFloat(prompt('人口 (百万):', '') || '0');
  const additionalInfo = prompt('附加信息:', '');
  
  earthRef.value.addOrUpdateLocation({
    name,
    latitude,
    longitude,
    population: isNaN(population) ? undefined : population,
    additionalInfo: additionalInfo || undefined
  });
};

// 删除地点
const removeLocation = () => {
  if (!earthRef.value) return;
  
  const name = prompt('要删除的城市名称:');
  if (name) {
    earthRef.value.removeLocation(name);
  }
};
</script>

<template>
  <div class="app-container">
    <div class="earth-wrapper">
      <Earth 
        ref="earthRef"
        :showLocations="showLocations" 
      />
    </div>
    
    <div class="controls">
      <h1>3D 地球模型</h1>
      <div class="control-buttons">
        <button @click="toggleLocations">{{ showLocations ? '隐藏地点' : '显示地点' }}</button>
        <button @click="addLocation">添加地点</button>
        <button @click="removeLocation">删除地点</button>
      </div>
      <div class="instructions">
        <p><strong>操作说明:</strong></p>
        <ul>
          <li>左键拖动: 旋转地球</li>
          <li>右键拖动: 平移视图</li>
          <li>滚轮: 缩放</li>
          <li>鼠标悬停在标记上: 显示地点信息</li>
        </ul>
      </div>
    </div>
  </div>
</template>

<style>
html, body {
  margin: 0;
  padding: 0;
  height: 100%;
  width: 100%;
  overflow: hidden;
  font-family: Arial, sans-serif;
}

#app {
  height: 100%;
  width: 100%;
}
</style>

<style scoped>
.app-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  width: 100%;
  background-color: #000;
  color: white;
}

.earth-wrapper {
  flex: 1;
  width: 100%;
}

.controls {
  position: absolute;
  top: 20px;
  left: 20px;
  background-color: rgba(0, 0, 0, 0.7);
  padding: 15px;
  border-radius: 8px;
  z-index: 100;
  max-width: 300px;
}

.control-buttons {
  display: flex;
  gap: 10px;
  margin-bottom: 15px;
  flex-wrap: wrap;
}

button {
  background-color: #4CAF50;
  color: white;
  border: none;
  padding: 8px 16px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  font-size: 14px;
  margin: 4px 2px;
  cursor: pointer;
  border-radius: 4px;
  transition: background-color 0.3s;
}

button:hover {
  background-color: #45a049;
}

.instructions {
  font-size: 14px;
}

.instructions ul {
  padding-left: 20px;
  margin-top: 5px;
}
</style>
