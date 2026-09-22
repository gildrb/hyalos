/// <reference types="vite-plus/client" />
/// <reference types="@webgpu/types" />
import type { HyalosAPI } from './types.ts';
declare global { interface Window { hyalos?: HyalosAPI; __hyalosBootTimer?: number } }
export {};
