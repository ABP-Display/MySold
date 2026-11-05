(() => {
  'use strict';
  let listener = null;
  let visibilityListener = null;
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
    if (visibilityListener) window.document?.removeEventListener('visibilitychange', visibilityListener);
    listener = null;
    visibilityListener = null;
  };
  window.mysoldStartShake = (onShake) => {
    window.mysoldStopShake();
    if (!window.DeviceMotionEvent) return;
    // Retain the bridge name and saved preference for existing installations.
    let reference = null, gravity = null, candidateSince = null, lastSample = null;
    let armed = true;
    const reset = () => {
      reference = gravity = candidateSince = lastSample = null;
      armed = true;
    };
    visibilityListener = reset;
    window.document?.addEventListener('visibilitychange', visibilityListener);
    listener = (event) => {
      if (window.document?.hidden) { reset(); return; }
      const a = event.accelerationIncludingGravity;
      if (!a || ![a.x, a.y, a.z].every(Number.isFinite)) return;
      const now = performance.now();
      // Reject bumps/translation rather than interpreting them as rotation.
      const magnitude = Math.hypot(a.x, a.y, a.z);
      const linear = event.acceleration;
      if (magnitude < 8 || magnitude > 11.8 ||
          (linear && [linear.x, linear.y, linear.z].every(Number.isFinite) &&
           Math.hypot(linear.x, linear.y, linear.z) > 2.5)) {
        candidateSince = null;
        return;
      }
      if (lastSample !== null && now - lastSample > 1500) reset();
      const dt = lastSample === null ? 0 : now - lastSample;
      lastSample = now;
      const vector = [a.x, a.y, a.z];
      if (!gravity) {
        gravity = vector;
        reference = vector.map(v => v / magnitude);
        return;
      }
      const alpha = 1 - Math.exp(-dt / 120);
      gravity = gravity.map((v, i) => v + alpha * (vector[i] - v));
      const length = Math.hypot(...gravity);
      if (length < 1) { candidateSince = null; return; }
      const cosine = gravity.reduce((sum, v, i) => sum + v / length * reference[i], 0);
      if (!armed) {
        if (cosine > Math.cos(30 * Math.PI / 180)) armed = true;
        return;
      }
      // A quarter turn (85 degrees allowing sensor noise), held for 300 ms.
      if (cosine > Math.cos(85 * Math.PI / 180)) { candidateSince = null; return; }
      candidateSince ??= now;
      if (now - candidateSince < 300) return;
      armed = false;
      candidateSince = null;
      onShake();
    };
    window.addEventListener('devicemotion', listener);
  };
})();
