/// <reference types="vite-plus/client" />
/// <reference types="@webgpu/types" />
import type { ExoAPI } from './types.ts';
declare global { interface Window { exo?: ExoAPI; __exoBootTimer?: number } }
export {};
