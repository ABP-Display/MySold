# Engine fallback fonts

Flutter 3.44.0 can request these fonts independently of the application's
TextTheme (for example while rendering an obscured PIN). The bootstrap sets
`fontFallbackBaseUrl` to this local directory so the strict same-origin CSP
does not cause repeated failed downloads and redraws.

Files are the unmodified WOFF2 fonts from `https://fonts.gstatic.com/s/` with
their original path, as listed in the Flutter engine's
`lib/web_ui/lib/src/engine/font_fallback_data.dart`. SIL Open Font licenses
are included. Noto Sans also covers French narrow no-break currency spacing.

When upgrading Flutter, verify these paths against the engine and exercise
the PIN, MFA and currency screens under the production CSP. Additional scripts
may require additional local fallback fonts; keep the CSP restricted to self.
