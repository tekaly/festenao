// A markdown page: themed headings, a table, links handled by the app.
import 'package:festenao_markdown/markdown.dart';
import 'package:material_ui/material_ui.dart';

const _page = '''
# Festival

Three days of **music** in the old town.

| Day | Stage |
|---|---|
| Friday | Main square |
| Saturday | Harbour |

See the [program](https://example.com/program) or the [map](app:/map).
''';

void main() {
  runApp(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4)),
      home: const PageScreen(),
    ),
  );
}

/// A scrollable markdown page.
class PageScreen extends StatelessWidget {
  /// Constructor.
  const PageScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Festival')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FestenaoMarkdownWidget(
          data: _page,
          // Merged over the styles of the theme.
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          onTapLink: (text, href, title) {
            // Open https links with url_launcher, route the app ones.
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$text: $href')));
          },
        ),
      ],
    ),
  );
}
