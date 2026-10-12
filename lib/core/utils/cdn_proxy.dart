/// Rewrites image URLs whose CDN does not send CORS headers so they can be
/// loaded by the Flutter web (CanvasKit) renderer, which fetches images via
/// XHR and is therefore subject to browser CORS rules.
///
/// Kitsu's media CDN (media.kitsu.app) serves images without
/// `Access-Control-Allow-Origin`, so we proxy them through images.weserv.nl,
/// which responds with permissive CORS headers and can resize on the fly.
String proxyCdnImage(String url, {int width = 500}) {
  if (url.isEmpty) return '';
  if (!url.startsWith('http')) return url;
  if (url.contains('wsrv.nl')) return url;

  final uri = Uri.tryParse(url);
  final host = uri?.host ?? '';
  final isKitsu =
      host.contains('media.kitsu.app') || host.contains('media.kitsu.io');

  if (!isKitsu) return url;

  final target = UrlSchemeEscape.escape(url);
  return 'https://wsrv.nl/?url=$target&w=$width';
}

// Minimal single-purpose encoder so we don't need imports here.
class UrlSchemeEscape {
  static String escape(String value) => Uri.encodeComponent(value);
}
