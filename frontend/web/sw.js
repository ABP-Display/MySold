// Never cache API responses or financial data on a shared device.
// Replaced with the dated build number and content hash after each build.
const BUILD = '__MYSOLD_BUILD_ID__';
const CACHE = `mysold-shell-${BUILD}`;
const SHELL = ['/', '/index.html', '/manifest.json', '/favicon.png'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)));
});
self.addEventListener('message', event => {
  if (event.data?.type === 'MYSOLD_GET_BUILD') event.ports?.[0]?.postMessage({build: BUILD});
  if (event.data?.type === 'MYSOLD_SKIP_WAITING') event.waitUntil(self.skipWaiting());
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(key => (key.startsWith('mysold-shell-') && key !== CACHE) || ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'].includes(key)).map(key => caches.delete(key))
  )).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin ||
      url.pathname.startsWith('/api/') || url.pathname === '/version.json') return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request, {cache: 'no-store'}).catch(() => caches.match('/index.html')));
  }
});
