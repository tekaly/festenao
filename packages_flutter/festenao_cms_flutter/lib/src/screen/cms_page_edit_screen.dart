import 'package:festenao_cms_flutter/src/provider/cms_page_providers.dart';
import 'package:festenao_cms_flutter/src/screen/cms_page_preview_screen.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A linkable item the host offers in the "presents" picker: an event, a
/// location... of its own content database.
class CmsLinkableItem {
  /// Item kind (see `cmsItemKinds`).
  final String kind;

  /// Item id.
  final String id;

  /// Display name.
  final String name;

  /// A linkable item.
  const CmsLinkableItem({
    required this.kind,
    required this.id,
    required this.name,
  });
}

/// Create or edit a page: title, slug, summary, markdown body with a live
/// preview, item link, tags, SEO fields, publish.
///
/// Reads and writes through [cmsPageSdbProvider]. [pageId] null creates a
/// page; [initialItem] pre-links the new page to an item (the "write a page
/// about this event" entry).
class CmsPageEditScreen extends ConsumerStatefulWidget {
  /// The page to edit, null to create one.
  final String? pageId;

  /// Item the new page presents.
  final CmsLinkableItem? initialItem;

  /// Items the "presents" picker offers, by kind; empty for a free text id.
  final List<CmsLinkableItem> linkableItems;

  /// True to only show the form (a member without write access).
  final bool readOnly;

  /// Called once saved (defaults to popping).
  final void Function(BuildContext context, SdbCmsPage page)? onSaved;

  /// An edit screen.
  const CmsPageEditScreen({
    super.key,
    required this.pageId,
    this.initialItem,
    this.linkableItems = const [],
    this.readOnly = false,
    this.onSaved,
  });

  @override
  ConsumerState<CmsPageEditScreen> createState() => _CmsPageEditScreenState();
}

class _CmsPageEditScreenState extends ConsumerState<CmsPageEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _itemIdCtrl = TextEditingController();
  final _seoTitleCtrl = TextEditingController();
  final _seoDescriptionCtrl = TextEditingController();
  final _heroUrlCtrl = TextEditingController();
  late final _tabs = TabController(length: 2, vsync: this);

  String _itemKind = cmsItemKindPage;
  var _published = false;
  var _noIndex = false;
  var _slugEdited = false;
  var _loaded = false;
  var _saving = false;
  SdbCmsPage? _page;

  bool get _isNew => widget.pageId == null;

  @override
  void initState() {
    super.initState();
    var item = widget.initialItem;
    if (item != null) {
      _itemKind = item.kind;
      _itemIdCtrl.text = item.id;
      _titleCtrl.text = item.name;
    }
    if (_isNew) {
      _loaded = true;
    }
    _titleCtrl.addListener(() {
      if (!_slugEdited) {
        _slugCtrl.text = cmsSlugify(_titleCtrl.text, fallback: '');
      }
      setState(() {});
    });
    _bodyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (var ctrl in [
      _titleCtrl,
      _slugCtrl,
      _summaryCtrl,
      _bodyCtrl,
      _tagsCtrl,
      _itemIdCtrl,
      _seoTitleCtrl,
      _seoDescriptionCtrl,
      _heroUrlCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _load(SdbCmsPage page) {
    _page = page;
    _titleCtrl.text = page.title.v ?? '';
    _slugCtrl.text = page.slug.v ?? '';
    _slugEdited = true;
    _summaryCtrl.text = page.summary.v ?? '';
    _bodyCtrl.text = page.body.v ?? '';
    _tagsCtrl.text = (page.tags.v ?? const <String>[]).join(', ');
    _itemKind = page.kind;
    _itemIdCtrl.text = page.itemId.v ?? '';
    _seoTitleCtrl.text = page.seoTitle.v ?? '';
    _seoDescriptionCtrl.text = page.seoDescription.v ?? '';
    _heroUrlCtrl.text = page.heroImage.v?.url.v ?? '';
    _published = page.isPublished;
    _noIndex = page.noIndex.v ?? false;
    _loaded = true;
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _apply(SdbCmsPage page) {
    page
      ..title.v = _titleCtrl.text.trim()
      ..slug.v = _emptyToNull(_slugCtrl.text)
      ..summary.v = _emptyToNull(_summaryCtrl.text)
      ..body.v = _bodyCtrl.text
      ..bodyFormat.v = cmsPageBodyFormatMarkdown
      ..tags.v = _tagsCtrl.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList()
      ..itemKind.v = _itemKind == cmsItemKindPage ? null : _itemKind
      ..itemId.v = _itemKind == cmsItemKindPage
          ? null
          : _emptyToNull(_itemIdCtrl.text)
      ..seoTitle.v = _emptyToNull(_seoTitleCtrl.text)
      ..seoDescription.v = _emptyToNull(_seoDescriptionCtrl.text)
      ..published.v = _published
      ..noIndex.v = _noIndex;
    var heroUrl = _emptyToNull(_heroUrlCtrl.text);
    if (heroUrl == null) {
      if (page.heroImage.v?.mediaId.v == null) {
        page.heroImage.v = null;
      } else {
        page.heroImage.v!.url.v = null;
      }
    } else {
      page.heroImage.v = (page.heroImage.v ?? CvCmsImage())..url.v = heroUrl;
    }
  }

  /// The page as the form describes it (preview).
  SdbCmsPage _draft() {
    var page = SdbCmsPage();
    var existing = _page;
    if (existing != null) {
      page.copyFrom(existing);
    }
    _apply(page);
    return page;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      var sdb = ref.read(cmsPageSdbProvider);
      SdbCmsPage saved;
      var pageId = widget.pageId;
      if (pageId == null) {
        var page = SdbCmsPage();
        _apply(page);
        saved = await sdb.addPage(page);
      } else {
        saved = (await sdb.updatePage(pageId, _apply))!;
      }
      if (!mounted) {
        return;
      }
      var onSaved = widget.onSaved;
      if (onSaved != null) {
        onSaved(context, saved);
      } else {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    var pageId = widget.pageId;
    if (pageId == null) {
      return;
    }
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this page?'),
        content: const Text('Its url will stop working.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(cmsPageSdbProvider).deletePage(pageId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    var pageId = widget.pageId;
    if (pageId != null && !_loaded) {
      var pageAsync = ref.watch(cmsPageProvider(pageId));
      var page = pageAsync.value;
      if (page != null) {
        _load(page);
      } else {
        return Scaffold(
          appBar: AppBar(title: const Text('Page')),
          body: pageAsync.when(
            data: (_) => const Center(child: Text('Page not found')),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        );
      }
    }
    var readOnly = widget.readOnly;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? 'New page'
              : (_titleCtrl.text.isEmpty ? 'Page' : _titleCtrl.text),
        ),
        actions: [
          if (!_isNew && !readOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
            ),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _saving ? null : _save,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Edit', icon: Icon(Icons.edit_note)),
            Tab(text: 'Preview', icon: Icon(Icons.visibility)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildForm(context, readOnly: readOnly),
          CmsPageView(page: _draft()),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool readOnly}) {
    var kinds = cmsItemKinds;
    var linkable = widget.linkableItems
        .where((item) => item.kind == _itemKind)
        .toList();
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'A title is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _slugCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Slug (url)',
              prefixText: '/page/',
              helperText: 'Derived from the title until edited, kept unique',
            ),
            onChanged: (_) => _slugEdited = true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _summaryCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Summary',
              helperText: 'Shown in lists and as the default meta description',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bodyCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Body (markdown)',
              alignLabelWithHint: true,
            ),
            minLines: 8,
            maxLines: 30,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _heroUrlCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Main image url',
              helperText: 'Open graph image, page header',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tagsCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Tags',
              helperText: 'Comma separated',
            ),
          ),
          const SizedBox(height: 24),
          Text('Presents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _itemKind,
            decoration: const InputDecoration(labelText: 'Kind'),
            items: [
              for (var kind in kinds)
                DropdownMenuItem(value: kind, child: Text(kind)),
            ],
            onChanged: readOnly
                ? null
                : (value) =>
                      setState(() => _itemKind = value ?? cmsItemKindPage),
          ),
          if (_itemKind != cmsItemKindPage) ...[
            const SizedBox(height: 12),
            if (linkable.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue:
                    linkable.any((item) => item.id == _itemIdCtrl.text)
                    ? _itemIdCtrl.text
                    : null,
                decoration: const InputDecoration(labelText: 'Item'),
                items: [
                  for (var item in linkable)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: readOnly
                    ? null
                    : (value) => setState(() => _itemIdCtrl.text = value ?? ''),
              )
            else
              TextFormField(
                controller: _itemIdCtrl,
                readOnly: readOnly,
                decoration: const InputDecoration(labelText: 'Item id'),
              ),
          ],
          const SizedBox(height: 24),
          Text('SEO', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _seoTitleCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Title tag',
              helperText: 'Defaults to the title',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _seoDescriptionCtrl,
            readOnly: readOnly,
            decoration: const InputDecoration(
              labelText: 'Meta description',
              helperText: 'Defaults to the summary, 160 characters',
            ),
            maxLength: 160,
            maxLines: 2,
          ),
          SwitchListTile(
            title: const Text('Hide from search engines'),
            subtitle: const Text('noindex'),
            value: _noIndex,
            onChanged: readOnly
                ? null
                : (value) => setState(() => _noIndex = value),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Published'),
            subtitle: const Text('Only published pages are served'),
            value: _published,
            onChanged: readOnly
                ? null
                : (value) => setState(() => _published = value),
          ),
          const SizedBox(height: 24),
          if (!readOnly)
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isNew ? 'Create' : 'Save'),
            ),
        ],
      ),
    );
  }
}
