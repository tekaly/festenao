import 'package:festenao_common_flutter/festenao_slug_flutter.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

/// The root the demo slugs live under: `app/demo/slug/<slug>`, visible in the
/// firestore explorer too.
const demoSlugRootPath = 'app/demo';

/// The demo project whose url the page edits.
const demoSlugProjectId = 'my_project';

/// A festival that moved from `festival` to `festival-2026` (the old url an
/// alias, still resolving) and a blog.
Future<void> fillDemoSlugs(Firestore firestore) async {
  var registry = FestenaoSlugRegistry(
    firestore: firestore,
    rootPath: demoSlugRootPath,
  );
  await registry.claim(
    slug: 'festival',
    entityType: 'project',
    entityId: 'fest',
  );
  await registry.claim(
    slug: 'festival-2026',
    entityType: 'project',
    entityId: 'fest',
    previousSlug: 'festival',
  );
  await registry.claim(slug: 'blog', entityType: 'project', entityId: 'blog');
}

/// Project urls: the slug field checking the registry as you type, claiming
/// one, and resolving a link (`<origin>/p/<slug>`) to its project.
class DemoSlugPage extends StatefulWidget {
  /// The demo firestore.
  final Firestore firestore;

  /// Project urls.
  const DemoSlugPage({super.key, required this.firestore});

  @override
  State<DemoSlugPage> createState() => _DemoSlugPageState();
}

class _DemoSlugPageState extends State<DemoSlugPage> {
  late final _registry = FestenaoSlugRegistry(
    firestore: widget.firestore,
    rootPath: demoSlugRootPath,
  );
  final _slug = TextEditingController();
  final _link = TextEditingController();
  var _status = FestenaoSlugStatus.empty;
  String? _current;
  String? _resolved;
  late Future<List<FsFestenaoSlug>> _slugs = _list();

  Future<List<FsFestenaoSlug>> _list() =>
      _registry.collection.query().get(widget.firestore);

  @override
  void dispose() {
    _slug.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    var slug = _slug.text;
    await _registry.claim(
      slug: slug,
      entityType: 'project',
      entityId: demoSlugProjectId,
      previousSlug: _current,
    );
    setState(() {
      _current = slug;
      _slugs = _list();
    });
  }

  Future<void> _resolve() async {
    var slug = festenaoSlugOptionsDefault.parse(
      _link.text,
      pathSegments: const [festenaoProjectUrlPathSegment],
    );
    var doc = slug == null ? null : await _registry.resolve(slug);
    setState(() {
      _resolved = doc == null
          ? 'No project there'
          : 'Project ${doc.entityId.v}'
                '${(doc.alias.v ?? false) ? ' (an old url of it)' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project urls')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'A project gets a readable url, unique in the app. Try "festival" '
          '(taken) or your own; the check runs as you type.',
        ),
        const SizedBox(height: 16),
        FestenaoSlugField(
          controller: _slug,
          currentSlug: _current,
          prefixText: 'my-app.web.app/p/',
          isAvailable: (slug) => _registry.isAvailable(
            slug,
            entityType: 'project',
            entityId: demoSlugProjectId,
          ),
          onStatusChanged: (status) => setState(() => _status = status),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _status == FestenaoSlugStatus.available ? _claim : null,
          child: const Text('Use this url'),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _link,
          decoration: const InputDecoration(
            labelText: 'Open a link',
            hintText: 'https://my-app.web.app/p/festival',
          ),
          onSubmitted: (_) => _resolve(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _resolve, child: const Text('Resolve')),
        if (_resolved != null) ...[const SizedBox(height: 8), Text(_resolved!)],
        const SizedBox(height: 24),
        Text('The registry', style: Theme.of(context).textTheme.titleMedium),
        FutureBuilder(
          future: _slugs,
          builder: (context, snapshot) => Column(
            children: [
              for (var doc in snapshot.data ?? const <FsFestenaoSlug>[])
                ListTile(
                  dense: true,
                  leading: Icon(
                    (doc.alias.v ?? false) ? Icons.history : Icons.link,
                  ),
                  title: Text('/p/${doc.slug}'),
                  subtitle: Text(
                    '${doc.entityType.v} ${doc.entityId.v}'
                    '${(doc.alias.v ?? false) ? ' · old url' : ''}',
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
