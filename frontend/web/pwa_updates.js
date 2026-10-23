// This value belongs to the running page, not to the latest server response.
const LOCAL_BUILD = '__MYSOLD_BUILD_VERSION__';
(() => {
  const supported = 'serviceWorker' in navigator && window.isSecureContext;
  const registration = supported
    ? navigator.serviceWorker.register('/sw.js', {updateViaCache: 'none'})
    : null;
  registration?.catch(() => {});
  let availableBuild = '';
  let availableManifest = null;
  let applying = null;
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
      return data;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function check() {
    if (!supported) return 'unsupported';
    if (!navigator.onLine) return 'offline';
    try {
      const latest = await serverBuild();
      availableManifest = latest;
      availableBuild = latest.build === LOCAL_BUILD ? '' : latest.build;
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

  function workerMatches(worker, manifest) {
    if (!worker) return Promise.resolve(false);
    return new Promise(resolve => {
      const channel = new MessageChannel();
      const timeout = setTimeout(() => finish(false), 3000);
      const finish = matches => {
        clearTimeout(timeout);
        channel.port1.close();
        channel.port2.close();
        resolve(matches);
      };
      channel.port1.onmessage = event => {
        const expected = manifest.contentHash ? `${manifest.build}-${manifest.contentHash}` : null;
        const build = event.data?.build;
        finish(typeof build === 'string' && (expected ? build === expected : build.startsWith(`${manifest.build}-`)));
      };
      try { worker.postMessage({type: 'MYSOLD_GET_BUILD'}, [channel.port2]); }
      catch (_) { finish(false); }
    });
  }

  function activate(worker, manifest) {
    return new Promise(resolve => {
      const timeout = setTimeout(() => finish(false), 20000);
      let finished = false;
      const finish = result => {
        if (finished) return;
        finished = true;
        clearTimeout(timeout);
        navigator.serviceWorker.removeEventListener('controllerchange', onChange);
        resolve(result);
      };
      const onChange = async () => finish(await workerMatches(navigator.serviceWorker.controller, manifest));
      navigator.serviceWorker.addEventListener('controllerchange', onChange);
      try { worker.postMessage({type: 'MYSOLD_SKIP_WAITING'}); }
      catch (_) { finish(false); }
    });
  }

  async function apply() {
    if (!supported || !navigator.onLine || !availableBuild) return false;
    try {
      const latest = await serverBuild();
      if (latest.build === LOCAL_BUILD || latest.build !== availableBuild ||
          latest.contentHash !== availableManifest?.contentHash) return false;
      const current = await registration;
      await current.update();
      if (current.installing) await waitForInstallation(current.installing);
      const worker = current.waiting || current.active;
      // Never reload while an old or unidentified worker still serves the app.
      if (!await workerMatches(worker, latest)) return false;
      if (current.waiting && !await activate(worker, latest)) return false;
      if (!await workerMatches(navigator.serviceWorker.controller, latest)) return false;
      // A distinct navigation URL also bypasses a stale HTTP navigation cache.
      const url = new URL(window.location.href);
      url.searchParams.set('mysold_update', latest.build);
      window.location.replace(url.href);
      return true;
    } catch (_) { return false; }
  }

  window.mysoldApplyUpdate = () => {
    if (!applying) applying = apply().finally(() => { applying = null; });
    return applying;
  };
})();
