# AGENTS.md - Development Guide for AI Agents

## Project Overview

This is a Vue 3 + TypeScript + Three.js 3D Earth visualization project. It renders an interactive 3D globe with location markers, orbital controls, and tooltips.

## Commands

### Install Dependencies
```bash
npm install
```

### Development
```bash
npm run dev          # Start Vite dev server
npm run preview     # Preview production build
```

### Build & Type Check
```bash
npm run build        # Type-check with vue-tsc then build with Vite
```

### Testing
No test framework is configured. For this project, manual verification via browser is expected.

### Type Checking Only
```bash
npx vue-tsc --noEmit    # Type-check without building
npx vue-tsc -b          # Build-mode type-check (used by npm run build)
```

## Code Style Guidelines

### Language & Framework
- Vue 3 with Composition API using `<script setup lang="ts">`
- TypeScript with strict mode enabled
- Three.js for 3D rendering

### TypeScript Configuration
The project uses strict TypeScript with these rules (from tsconfig.app.json):
- `strict: true`
- `noUnusedLocals: true`
- `noUnusedParameters: true`
- `noFallthroughCasesInSwitch: true`
- `noUncheckedSideEffectImports: true`
- `erasableSyntaxOnly: true`

### Imports

**Vue core:**
```typescript
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
```

**Three.js:**
```typescript
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
```

**Vue components:**
```typescript
import Earth from './components/Earth.vue';
```

### Naming Conventions

- **Components**: PascalCase (e.g., `Earth.vue`, `HelloWorld.vue`)
- **Interfaces**: PascalCase with descriptive names (e.g., `LocationInfo`)
- **Props**: camelCase (e.g., `showLocations`)
- **Variables**: camelCase (e.g., `earthRef`, `tooltipEl`)
- **Constants**: camelCase or UPPER_SNAKE_CASE for true constants
- **Files**: kebab-case for components, PascalCase for types/utilities

### Vue Component Structure

```vue
<script setup lang="ts">
// 1. Imports
import { ref, onMounted } from 'vue';

// 2. Types/Interfaces (if needed)
interface LocationInfo {
  name: string;
  latitude: number;
  longitude: number;
}

// 3. Props
const props = defineProps<{
  showLocations?: boolean;
}>();

// 4. Reactive state
const container = ref<HTMLElement | null>(null);

// 5. Non-reactive variables (Three.js objects)
let scene: THREE.Scene;
let camera: THREE.PerspectiveCamera;

// 6. Functions
const initThree = () => { /* ... */ };

// 7. Lifecycle hooks
onMounted(() => { initThree(); });

// 8. Expose methods (if needed)
defineExpose({ methodName });
</script>

<template>
  <!-- Template content -->
</template>

<style scoped>
/* Scoped styles */
</style>
```

### Error Handling

- Use try-catch for async operations
- Log errors with console.error for debugging
- Handle texture load failures via textureLoader.manager.onError
- Always null-check Three.js objects before use

### CSS Guidelines

- Use `<style scoped>` for component-specific styles
- Use separate `<style>` (non-scoped) for global styles
- Follow existing patterns:
  - Flexbox for layout
  - Absolute positioning for overlays
  - RGBA for semi-transparent backgrounds
  - Border-radius for rounded corners

### Three.js Best Practices

- Always clean up in `onUnmounted`: remove event listeners, cancel animation frames, dispose renderers
- Use `requestAnimationFrame` for render loops
- Set pixel ratio for device compatibility
- Use `OrbitControls.enableDamping` for smooth interaction
- Dispose geometries and materials when removing objects

## Project Structure

```
3D-Earth/
├── public/textures/      # Earth texture images
├── src/
│   ├── assets/           # Static assets (GeoJSON data)
│   │   └── world.zh.json # World country boundaries (Chinese names)
│   ├── components/       # Vue components
│   │   ├── Earth.vue     # 3D Earth component
│   │   └── HelloWorld.vue
│   ├── App.vue           # Main app component
│   ├── main.ts           # Entry point
│   ├── style.css         # Global styles
│   └── vite-env.d.ts     # Vite type definitions
├── index.html
├── vite.config.ts
├── tsconfig.json
└── package.json
```

## Common Patterns

### Country Borders Feature
The Earth component supports displaying country borders with hover information:
- Import GeoJSON: `import worldGeoJSON from '../assets/world.zh.json';`
- Use prop: `<Earth :showCountries="true" />`
- Toggle via ref: `earthRef.value.toggleCountries()`

### Adding New Location Data
Edit the `locations` ref in `src/components/Earth.vue`:
```typescript
const locations = ref<LocationInfo[]>([
  { name: 'CityName', latitude: XX.XX, longitude: XX.XX, population: X.XX, additionalInfo: 'info' },
]);
```

### Adding New Dependencies
```bash
npm install <package-name>
npm install -D @types/<package-name>  # If TypeScript types needed
```

## Notes

- No ESLint or Prettier is configured - code style follows Vue/TypeScript defaults
- No test framework exists - verify changes manually in browser
- The project uses pnpm-lock.yaml but npm commands work fine
