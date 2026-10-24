{{flutter_js}}
{{flutter_build_config}}
// Full CanvasKit includes its own text segmentation. The Chromium variant uses
// the deprecated Intl.v8BreakIterator API.
_flutter.loader.load({config: {
  canvasKitBaseUrl: '/canvaskit/',
  canvasKitVariant: 'full',
  // Engine-generated text (including obscured PIN fields) can bypass the
  // application's TextTheme fallback list. Keep its fallback fonts local too.
  fontFallbackBaseUrl: '/font-fallbacks/'
}});
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
