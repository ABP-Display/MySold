import 'package:web/web.dart' as web;

bool openPublicDocument(String path) {
  if (!const {
    '/',
    '/conditions/',
    '/confidentialite/',
    '/cookies/',
    '/mentions-legales/',
  }.contains(path)) {
    return false;
  }
  web.window.open(
    Uri.base.resolve(path).toString(),
    '_blank',
    'noopener,noreferrer',
  );
  return true;
}
