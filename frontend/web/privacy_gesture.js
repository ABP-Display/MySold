(() => {
  'use strict';
  let listener = null;
  window.mysoldRequestMotionPermission = async () => {
    if (!window.isSecureContext || !window.DeviceMotionEvent) return false;
    try {
      if (typeof window.DeviceMotionEvent.requestPermission === 'function') {
        return await window.DeviceMotionEvent.requestPermission() === 'granted';
      }
      // Confirm that the device actually delivers sensor data before enabling.
      return await new Promise((resolve) => {
        const probe = (event) => {
          const a = event.accelerationIncludingGravity;
          if (a && [a.x, a.y, a.z].every(Number.isFinite)) finish(true);
        };
        const finish = (available) => {
          window.clearTimeout(timeout);
          window.removeEventListener('devicemotion', probe);
          resolve(available);
        };
        const timeout = window.setTimeout(() => finish(false), 2000);
        window.addEventListener('devicemotion', probe);
      });
    } catch (_) { return false; }
  };
  window.mysoldStopShake = () => {
    if (listener) window.removeEventListener('devicemotion', listener);
    listener = null;
  };
  window.mysoldStartShake = (onShake) => {
    window.mysoldStopShake();
    if (!window.DeviceMotionEvent) return;
    let lastShake = -Infinity;
    listener = (event) => {
      const a = event.accelerationIncludingGravity;
      if (!a || ![a.x, a.y, a.z].every(Number.isFinite)) return;
      const now = performance.now();
      if (Math.hypot(a.x, a.y, a.z) < 22 || now - lastShake < 1200) return;
      lastShake = now;
      onShake();
    };
    window.addEventListener('devicemotion', listener);
  };
})();
