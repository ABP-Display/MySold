{{flutter_js}}
{{flutter_build_config}}
// Keep the black startup cover until Flutter has painted its first frame.
window.addEventListener?.('flutter-first-frame', () => {
  document.getElementById('mysold-startup')?.remove();
}, {once: true});
// Full CanvasKit includes its own text segmentation. The Chromium variant uses
// the deprecated Intl.v8BreakIterator API.
_flutter.loader.load({config: {
  canvasKitBaseUrl: '/canvaskit/',
  canvasKitVariant: 'full',
  // Engine-generated text (including obscured PIN fields) can bypass the
  // application's TextTheme fallback list. Keep its fallback fonts local too.
  fontFallbackBaseUrl: '/font-fallbacks/'
}});
