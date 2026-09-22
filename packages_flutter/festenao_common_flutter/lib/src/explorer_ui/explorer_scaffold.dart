import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

import 'explorer_chip.dart';

/// One step of an [ExplorerBreadcrumb].
class ExplorerCrumb {
  /// What it says.
  final String label;

  /// Going back to it, null for the step the screen is on.
  final VoidCallback? onTap;

  /// Crumb [label].
  const ExplorerCrumb(this.label, {this.onTap});
}

/// The path of what is on screen, a step at a time.
///
/// It is what says where a record sits — the instance, the collection, the
/// document — without the title having to spell it out.
class ExplorerBreadcrumb extends StatelessWidget {
  /// The steps, the last one being where the screen is.
  final List<ExplorerCrumb> crumbs;

  /// Breadcrumb of [crumbs].
  const ExplorerBreadcrumb({super.key, required this.crumbs});

  /// The crumbs of a path, its segments, [root] first.
  ///
  /// [onTap] is given how many segments to keep, so a caller pops back to
  /// that depth.
  static List<ExplorerCrumb> ofPath(
    String path, {
    required String root,
    void Function(int depth)? onTap,
  }) {
    var parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return [
      ExplorerCrumb(root, onTap: onTap == null ? null : () => onTap(0)),
      for (var index = 0; index < parts.length; index++)
        ExplorerCrumb(
          parts[index],
          onTap: index == parts.length - 1 || onTap == null
              ? null
              : () => onTap(index + 1),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var (index, crumb) in crumbs.indexed) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                ),
              InkWell(
                onTap: crumb.onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    crumb.label,
                    style: index == crumbs.length - 1
                        ? style?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          )
                        : style,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The small uppercase label above a list: `COLLECTIONS`, `STORES`, `FIELDS`.
class ExplorerSectionHeader extends StatelessWidget {
  /// What it says, shown uppercase.
  final String label;

  /// A badge at the end of the line, a count as a rule.
  final Widget? trailing;

  /// Header [label].
  const ExplorerSectionHeader({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: explorerChipFontSize,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The line at the bottom of an explorer, in monospace: where it is, how much
/// it holds, what it is waiting on.
class ExplorerStatusBar extends StatelessWidget {
  /// What it says on the left.
  final String message;

  /// Badges on the right.
  final List<Widget> trailing;

  /// Status bar saying [message].
  const ExplorerStatusBar({
    super.key,
    required this.message,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                overflow: TextOverflow.ellipsis,
                style: (theme.textTheme.labelSmall ?? const TextStyle())
                    .copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: explorerChipFontSize,
                      fontFamily: festenaoMonospaceFontFamily,
                    ),
              ),
            ),
            for (var widget in trailing) ...[const SizedBox(width: 6), widget],
          ],
        ),
      ),
    );
  }
}

/// The frame every explorer screen is built in: an app bar, the path below
/// it, the list, and the status line at the bottom.
///
/// Sharing the frame is what makes the explorers feel like one tool rather
/// than four: the same places hold the same things whatever is being browsed.
class ExplorerScaffold extends StatelessWidget {
  /// The title of the app bar.
  final String title;

  /// The path of what is shown, above the body.
  final List<ExplorerCrumb>? crumbs;

  /// The actions of the app bar.
  final List<Widget> actions;

  /// Shown before the actions, saying what state the screen is in.
  final Widget? stateChip;

  /// The list, the editor, whatever the screen is.
  final Widget body;

  /// The line at the bottom, none when null.
  final Widget? statusBar;

  /// What the screen creates, none when null.
  final Widget? floatingActionButton;

  /// True to show the padlock of a read only view.
  final bool isReadOnly;

  /// Screen titled [title].
  const ExplorerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.crumbs,
    this.actions = const [],
    this.stateChip,
    this.statusBar,
    this.floatingActionButton,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, overflow: TextOverflow.fade, softWrap: false),
      actions: [
        if (stateChip != null) ...[stateChip!, const SizedBox(width: 8)],
        if (isReadOnly) ...[
          const ExplorerChip(label: 'read only', icon: Icons.lock_outline),
          const SizedBox(width: 8),
        ],
        ...actions,
      ],
    ),
    body: Column(
      children: [
        if (crumbs != null && crumbs!.isNotEmpty)
          ExplorerBreadcrumb(crumbs: crumbs!),
        Expanded(child: body),
        ?statusBar,
      ],
    ),
    floatingActionButton: floatingActionButton,
  );
}
