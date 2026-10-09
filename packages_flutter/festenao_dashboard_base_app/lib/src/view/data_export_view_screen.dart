import 'dart:convert';
import 'dart:typed_data';

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_theme/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_file_download/download_file.dart';

/// Shows a text export (a jsonl database export for instance) in a monospace
/// font: line wrap on or off (scrolling sideways when off), pinch to zoom,
/// and a download (the browser downloads it on the web, a save dialog
/// elsewhere).
class DataExportViewScreen extends StatefulWidget {
  /// The app bar title.
  final String title;

  /// The text.
  final String content;

  /// The name of the downloaded file, its extension giving its type
  /// (`.jsonl` for a database export).
  final String filename;

  /// A text export.
  const DataExportViewScreen({
    super.key,
    required this.title,
    required this.content,
    required this.filename,
  });

  @override
  State<DataExportViewScreen> createState() => _DataExportViewScreenState();
}

class _DataExportViewScreenState extends State<DataExportViewScreen> {
  var _wrap = false;

  Future<void> _download() async {
    var intl = festenaoAdminAppIntl(context);
    var bytes = Uint8List.fromList(utf8.encode(widget.content));
    await downloadFile(
      DownloadFileInfo(
        filename: widget.filename,
        data: bytes,
        mimeType: filenameMimeType(widget.filename),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(intl.exportDownloadStarted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    // JetBrains Mono when the app declares it, the platform monospace
    // otherwise.
    const textStyle = TextStyle(
      fontFamily: festenaoMonospaceFontFamily,
      fontFamilyFallback: ['monospace'],
      fontSize: 12,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_wrap ? Icons.wrap_text : Icons.wrap_text_outlined),
            tooltip: _wrap ? intl.exportWrapOff : intl.exportWrapOn,
            onPressed: () => setState(() => _wrap = !_wrap),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: intl.exportDownload,
            onPressed: _download,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          var text = _wrap
              ? SizedBox(
                  width: constraints.maxWidth,
                  child: Text(widget.content, style: textStyle),
                )
              : Text(widget.content, style: textStyle, softWrap: false);
          return InteractiveViewer(
            constrained: false,
            minScale: 0.5,
            maxScale: 6,
            boundaryMargin: const EdgeInsets.all(48),
            child: Padding(padding: const EdgeInsets.all(12), child: text),
          );
        },
      ),
    );
  }
}
