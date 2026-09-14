import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The origin of the app, with a trailing `/`.
///
/// The origin, not `Uri.base`: the latter is the *current* location, so a
/// link built from a nested screen would be mangled. Off the web there is no
/// origin (`Uri.base` is a `file:` uri), the link is then relative — pass
/// [defaultBaseUrl] (the hosting url of the app) so a link shared from a
/// desktop or mobile build still opens somewhere.
String appShareBaseUrl({String? defaultBaseUrl}) {
  var base = Uri.base;
  if (base.isScheme('http') || base.isScheme('https')) {
    return '${base.origin}/';
  }
  if (defaultBaseUrl != null) {
    return defaultBaseUrl.endsWith('/') ? defaultBaseUrl : '$defaultBaseUrl/';
  }
  return '/';
}

/// The absolute link of an app [location] (`/playlist/123`), see
/// [appShareBaseUrl].
String appShareLink(String location, {String? defaultBaseUrl}) {
  var base = appShareBaseUrl(defaultBaseUrl: defaultBaseUrl);
  if (location.startsWith('/')) {
    location = location.substring(1);
  }
  return '$base$location';
}

/// One shareable link with its label, as listed by [showShareLinksDialog].
class ShareLinkItem {
  /// What the link opens (`View`, `Play`...).
  final String label;

  /// The link.
  final String url;

  /// One shareable link.
  const ShareLinkItem({required this.label, required this.url});
}

/// Shows the links to share, each with a copy button (and an open button when
/// [onOpen] is given).
///
/// Returns once the dialog is closed.
Future<void> showShareLinksDialog(
  BuildContext context, {
  required String title,
  required List<ShareLinkItem> links,
  String? message,
  Future<void> Function(String url)? onOpen,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message),
              ),
            for (var link in links)
              ShareLinkTile(
                label: link.label,
                url: link.url,
                onOpen: onOpen == null ? null : () => onOpen(link.url),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// A link with a copy button (and an open button when [onOpen] is given).
class ShareLinkTile extends StatelessWidget {
  /// What the link opens.
  final String label;

  /// The link.
  final String url;

  /// Opens the link, null hides the button.
  final VoidCallback? onOpen;

  /// A link with a copy button.
  const ShareLinkTile({
    super.key,
    required this.label,
    required this.url,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: SelectableText(url),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(SnackBar(content: Text('Copied $label link')));
              }
            },
          ),
          if (onOpen != null)
            IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.open_in_new),
              onPressed: onOpen,
            ),
        ],
      ),
    );
  }
}
