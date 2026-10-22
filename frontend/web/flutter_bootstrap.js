{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({config: {canvasKitBaseUrl: '/canvaskit/'}});
window.mysoldRequestNotifications = async () => {
  if (!('Notification' in window)) return 'denied';
  return Notification.requestPermission();
};
window.mysoldNotify = async (title, body) => {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  try {
    const registration = await navigator.serviceWorker.ready;
    await registration.showNotification(title, {body, icon: '/icons/Icon-192.png'});
  } catch (_) { /* Unsupported browsers still show the in-app alert. */ }
};
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js'));
}
