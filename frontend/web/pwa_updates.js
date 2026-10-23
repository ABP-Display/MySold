// This value belongs to the running page, not to the latest server response.
const LOCAL_BUILD = '__MYSOLD_BUILD_VERSION__';
(() => {
  const supported = 'serviceWorker' in navigator && window.isSecureContext;
  const registration = supported
    ? navigator.serviceWorker.register('/sw.js', {updateViaCache: 'none'})
    : null;
  registration?.catch(() => {});
  let availableBuild = '';
  let checking = null;
  window.mysoldBuildVersion = LOCAL_BUILD;
  window.mysoldUpdateVersion = '';

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

  async function serverBuild() {
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), 10000);
    try {
      const response = await fetch('/version.json', {cache: 'no-store', signal: abort.signal});
      if (!response.ok) throw new Error('Version unavailable');
      const data = await response.json();
      if (typeof data.build !== 'string' || !/^\d{4}\.\d{2}\.\d{2}\.\d{4}$/.test(data.build)) {
        throw new Error('Invalid version');
      }
      return data.build;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function check() {
    if (!supported) return 'unsupported';
    if (!navigator.onLine) return 'offline';
    try {
      const latest = await serverBuild();
      availableBuild = latest === LOCAL_BUILD ? '' : latest;
      window.mysoldUpdateVersion = availableBuild;
      if (!availableBuild) return 'latest';
      const current = await registration;
      await current.update();
      if (current.installing) await waitForInstallation(current.installing);
      // Another tab may already have activated the worker; this page still runs
      // its original build and needs the user's consent before reloading.
      return 'available';
    } catch (_) {
      return navigator.onLine ? 'error' : 'offline';
    }
  }

  window.mysoldCheckForUpdate = () => {
    if (!checking) checking = check().finally(() => { checking = null; });
    return checking;
  };

  window.mysoldApplyUpdate = async () => {
    if (!supported || !navigator.onLine || !availableBuild) return false;
    if (await serverBuild() === LOCAL_BUILD) return false;
    const current = await registration;
    if (!current.waiting) {
      window.location.reload();
      return true;
    }
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
