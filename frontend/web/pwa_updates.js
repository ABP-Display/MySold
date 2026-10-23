// Updates are activated only after the user confirms in Settings.
(() => {
  const supported = 'serviceWorker' in navigator && window.isSecureContext;
  const registration = supported
    ? navigator.serviceWorker.register('/sw.js', {updateViaCache: 'none'})
    : null;
  // Keep startup usable if offline or registration is blocked.
  registration?.catch(() => {});

  function waitForInstallation(worker) {
    if (worker.state === 'redundant') return Promise.reject(new Error('Installation failed'));
    if (['installed', 'activated'].includes(worker.state)) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => finish(new Error('Update timed out')), 20000);
      const onState = () => {
        if (worker.state === 'redundant') finish(new Error('Installation failed'));
        else if (['installed', 'activated'].includes(worker.state)) finish();
      };
      function finish(error) {
        clearTimeout(timeout);
        worker.removeEventListener('statechange', onState);
        error ? reject(error) : resolve();
      }
      worker.addEventListener('statechange', onState);
      onState();
    });
  }

  window.mysoldCheckForUpdate = async () => {
    if (!supported) return 'unsupported';
    if (!navigator.onLine) return 'offline';
    try {
      const current = await registration;
      await current.update();
      if (current.installing) await waitForInstallation(current.installing);
      return current.waiting ? 'available' : 'latest';
    } catch (_) {
      return navigator.onLine ? 'error' : 'offline';
    }
  };

  window.mysoldApplyUpdate = async () => {
    if (!supported) return false;
    const current = await registration;
    if (!current.waiting) return false;
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        navigator.serviceWorker.removeEventListener('controllerchange', onChange);
        reject(new Error('Activation timed out'));
      }, 20000);
      const onChange = () => {
        clearTimeout(timeout);
        navigator.serviceWorker.removeEventListener('controllerchange', onChange);
        resolve(true);
        window.location.reload();
      };
      navigator.serviceWorker.addEventListener('controllerchange', onChange);
      current.waiting.postMessage({type: 'MYSOLD_SKIP_WAITING'});
    });
  };
})();
