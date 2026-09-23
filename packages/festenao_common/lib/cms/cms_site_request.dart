/// A request to a cms site served below a path: the site base url derived
/// from the request, the path left below it.
///
/// The same function answers at several urls, each giving the site another
/// base url:
///
/// ```
/// https://<hosting>/cms/<projectId>/<dataId>/page/<slug>    hosting rewrite
/// https://cmsdev-<hash>-ew.a.run.app/<projectId>/<dataId>/…  deployed function
/// http://localhost:8040/cmsdev/<projectId>/<dataId>/…        local runner
/// ```
///
/// [CmsSiteRequest.fromUrl] strips the mount (`cms`, the function name), and
/// the site ids are then moved into the base url with [shift].
class CmsSiteRequest {
  /// The base url of what the request reached so far, ending with `/`.
  final Uri baseUrl;

  /// The path segments below [baseUrl].
  final List<String> segments;

  /// A request below [baseUrl].
  CmsSiteRequest({required Uri baseUrl, this.segments = const []})
    : baseUrl = _withTrailingSlash(baseUrl);

  /// The request for [url].
  ///
  /// Its first path segment is the mount when it is one of [mountNames] (the
  /// hosting path, the function name), kept in the base url.
  ///
  /// Behind firebase hosting or a proxy, the request url is the one of the
  /// function: [forwardedHost] (`x-forwarded-host`) and [forwardedProto]
  /// (`x-forwarded-proto`) give the url the visitor typed, the one the links
  /// of the site must use. Invalid values are ignored.
  factory CmsSiteRequest.fromUrl(
    Uri url, {
    Iterable<String> mountNames = const [],
    String? forwardedHost,
    String? forwardedProto,
  }) {
    var segments = url.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    var mount = <String>[];
    if (segments.isNotEmpty && mountNames.contains(segments.first)) {
      mount.add(segments.removeAt(0));
    }
    var scheme = _forwardedProto(forwardedProto) ?? url.scheme;
    var host = url.host;
    var port = url.hasPort ? url.port : null;
    var forwarded = _forwardedHost(forwardedHost);
    if (forwarded != null) {
      host = forwarded.host;
      port = forwarded.port;
    }
    var baseUrl = Uri(
      scheme: scheme,
      host: host,
      port: port,
      pathSegments: [...mount, ''],
    );
    return CmsSiteRequest(baseUrl: baseUrl, segments: segments);
  }

  /// The path below [baseUrl] (`page/<slug>`, `''` for the index).
  String get path => segments.join('/');

  /// The request whose base url takes the first [count] segments (the site
  /// ids: `<projectId>/<dataId>`), null when there are not that many.
  CmsSiteRequest? shift([int count = 1]) {
    if (segments.length < count) {
      return null;
    }
    return CmsSiteRequest(
      baseUrl: baseUrl.replace(
        pathSegments: [
          ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
          ...segments.take(count),
          '',
        ],
      ),
      segments: segments.sublist(count),
    );
  }

  static Uri _withTrailingSlash(Uri url) =>
      url.path.endsWith('/') ? url : url.replace(path: '${url.path}/');

  static String? _forwardedProto(String? value) {
    var proto = _firstForwarded(value)?.toLowerCase();
    return (proto == 'https' || proto == 'http') ? proto : null;
  }

  static final _hostRegExp = RegExp(r'^[A-Za-z0-9.-]+(:\d{1,5})?$');

  static ({String host, int? port})? _forwardedHost(String? value) {
    var host = _firstForwarded(value);
    if (host == null || !_hostRegExp.hasMatch(host)) {
      return null;
    }
    var index = host.indexOf(':');
    if (index == -1) {
      return (host: host.toLowerCase(), port: null);
    }
    return (
      host: host.substring(0, index).toLowerCase(),
      port: int.parse(host.substring(index + 1)),
    );
  }

  /// A forwarded header holds one value per proxy, the first is the client
  /// one.
  static String? _firstForwarded(String? value) {
    var first = value?.split(',').first.trim();
    return (first == null || first.isEmpty) ? null : first;
  }

  @override
  String toString() => 'CmsSiteRequest($baseUrl, $path)';
}
