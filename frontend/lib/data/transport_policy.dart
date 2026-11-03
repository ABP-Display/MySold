/// Remote credentials and financial data require TLS. Loopback HTTP remains
/// available for local installation and development.
bool isSecureApiOrigin(Uri uri) =>
    uri.scheme == 'https' ||
    (uri.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '::1', '[::1]'}.contains(uri.host));
