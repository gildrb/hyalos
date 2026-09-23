import type { StudioCamera } from './model.ts';
import {
  DEFAULT_PITCH,
  DEFAULT_RADIUS,
  DEFAULT_YAW,
  clampPitch,
} from '../../glass-sculpture/camera.ts';

const clampRadius = (radius: number) => Math.max(0.2,Math.min(6.5,radius));
const ORBIT_SPEED = 0.006;
const DOLLY_SPEED = 0.0016;
const CAMERA_EASE = 14;
const LIGHT_EASE = 5;
const LIGHT_HOLD_SECONDS = 2.5;

export function installPointerInput(canvas: HTMLCanvasElement, initial?: { camera: StudioCamera; light: { azimuth: number; elevation: number } }) {
  let targetYaw = initial?.camera.yaw ?? DEFAULT_YAW;
  let targetPitch = initial?.camera.pitch ?? DEFAULT_PITCH;
  let targetRadius = initial ? initial.camera.radius/(initial.camera.lens ?? 1) : DEFAULT_RADIUS;
  let yaw = targetYaw;
  let pitch = targetPitch;
  let radius = targetRadius;
  let targetLightAzimuth = initial?.light.azimuth ?? 0.9;
  let targetLightElevation = initial?.light.elevation ?? 0.5;
  let lightAzimuth = targetLightAzimuth;
  let lightElevation = targetLightElevation;
  let hoverRemaining = 0;
  let elapsed = 0;
  let activePointer: number | undefined;
  let lightMotion: 'fixed' | 'pointer' | 'drift' = 'fixed';
  let previousX = 0;
  let previousY = 0;
  const previousTouchAction = canvas.style.touchAction;
  canvas.style.touchAction = 'none';

  const steerLight = (event: PointerEvent) => {
    if (!event.isPrimary || lightMotion!=='pointer') return;
    const rect = canvas.getBoundingClientRect();
    const x = (event.clientX - rect.left) / Math.max(1, rect.width);
    const y = (event.clientY - rect.top) / Math.max(1, rect.height);
    targetLightAzimuth = (x - 0.5) * 3.6;
    targetLightElevation = 0.15 + (1 - y) * 1.0;
    hoverRemaining = LIGHT_HOLD_SECONDS;
  };

  const down = (event: PointerEvent) => {
    if (!event.isPrimary || activePointer !== undefined) return;
    activePointer = event.pointerId;
    previousX = event.clientX;
    previousY = event.clientY;
    canvas.setPointerCapture(event.pointerId);
  };

  const move = (event: PointerEvent) => {
    if (activePointer === undefined) {
      steerLight(event);
      return;
    }
    if (event.pointerId !== activePointer) return;
    targetYaw -= (event.clientX - previousX) * ORBIT_SPEED;
    targetPitch = clampPitch(targetPitch + (event.clientY - previousY) * ORBIT_SPEED);
    previousX = event.clientX;
    previousY = event.clientY;
  };

  const finishDrag = (event: PointerEvent) => {
    if (event.pointerId !== activePointer) return;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    activePointer = undefined;
  };

  const lostCapture = (event: PointerEvent) => {
    if (event.pointerId === activePointer) activePointer = undefined;
  };

  const wheel = (event: WheelEvent) => {
    event.preventDefault();
    targetRadius = clampRadius(targetRadius * Math.exp(event.deltaY * DOLLY_SPEED));
  };

  const keyboard = (event: KeyboardEvent) => {
    if(event.altKey || event.ctrlKey || event.metaKey)return;
    const step=event.shiftKey ? 0.12 : 0.04;
    if(event.key==='ArrowLeft')targetYaw+=step;
    else if(event.key==='ArrowRight')targetYaw-=step;
    else if(event.key==='ArrowUp')targetPitch=clampPitch(targetPitch-step);
    else if(event.key==='ArrowDown')targetPitch=clampPitch(targetPitch+step);
    else if(event.key==='+' || event.key==='=')targetRadius=clampRadius(targetRadius*0.9);
    else if(event.key==='-')targetRadius=clampRadius(targetRadius/0.9);
    else return;
    event.preventDefault();
  };
  canvas.addEventListener('keydown',keyboard);
  canvas.addEventListener('pointerdown', down);
  canvas.addEventListener('pointermove', move, { passive: true });
  canvas.addEventListener('pointerup', finishDrag);
  canvas.addEventListener('pointercancel', finishDrag);
  canvas.addEventListener('lostpointercapture', lostCapture);
  canvas.addEventListener('wheel', wheel, { passive: false });

  return {
    restore(state: { camera: StudioCamera; light: { azimuth: number; elevation: number } }) {
      elapsed = 0;
      targetYaw = yaw = state.camera.yaw;
      targetPitch = pitch = clampPitch(state.camera.pitch);
      targetRadius = radius = clampRadius(state.camera.radius/(state.camera.lens ?? 1));
      targetLightAzimuth = lightAzimuth = state.light.azimuth;
      targetLightElevation = lightElevation = state.light.elevation;
      hoverRemaining = LIGHT_HOLD_SECONDS;
    },
    get camera() {
      return { yaw, pitch, radius: Math.max(1.6,radius), lens: Math.max(1,1.6/radius) };
    },
    get light() {
      return { azimuth: lightAzimuth, elevation: lightElevation };
    },
    advance(deltaTime: number, motion: 'fixed' | 'pointer' | 'drift' = 'fixed') {
      lightMotion=motion;
      const dt = Math.max(0, Math.min(0.1, deltaTime));
      elapsed += dt;
      hoverRemaining = Math.max(0, hoverRemaining - dt);
      if (hoverRemaining === 0 && lightMotion==='drift') {
        targetLightAzimuth = 0.9 + Math.sin(elapsed * 0.23) * 1.6;
        targetLightElevation = 0.45 + Math.sin(elapsed * 0.37) * 0.3;
      }
      const cameraBlend = 1 - Math.exp(-CAMERA_EASE * dt);
      const lightBlend = 1 - Math.exp(-LIGHT_EASE * dt);
      yaw += (targetYaw - yaw) * cameraBlend;
      pitch += (targetPitch - pitch) * cameraBlend;
      radius += (targetRadius - radius) * cameraBlend;
      lightAzimuth += (targetLightAzimuth - lightAzimuth) * lightBlend;
      lightElevation += (targetLightElevation - lightElevation) * lightBlend;
    },
    dispose() {
      canvas.removeEventListener('keydown',keyboard);
      canvas.removeEventListener('pointerdown', down);
      canvas.removeEventListener('pointermove', move);
      canvas.removeEventListener('pointerup', finishDrag);
      canvas.removeEventListener('pointercancel', finishDrag);
      canvas.removeEventListener('lostpointercapture', lostCapture);
      canvas.removeEventListener('wheel', wheel);
      if (activePointer !== undefined && canvas.hasPointerCapture(activePointer)) {
        canvas.releasePointerCapture(activePointer);
      }
      activePointer = undefined;
      canvas.style.touchAction = previousTouchAction;
    },
  };
}
