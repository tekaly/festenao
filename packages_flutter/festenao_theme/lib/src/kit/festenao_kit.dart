import 'package:festenao_theme/src/design/festenao_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The width classes of the screens.
enum FkWidth {
  /// A phone.
  compact,

  /// A tablet, a small window.
  medium,

  /// A desk.
  expanded;

  /// The class of [width].
  static FkWidth of(double width) {
    if (width >= FestenaoSpace.expanded) {
      return expanded;
    }
    if (width >= FestenaoSpace.medium) {
      return medium;
    }
    return compact;
  }

  /// The page padding.
  double get padding =>
      this == compact ? FestenaoSpace.pagePhone : FestenaoSpace.pageDesk;
}

/// A page body: scrolls, pads, caps the width.
class FkPage extends StatelessWidget {
  /// The content.
  final List<Widget> children;

  /// The maximum width of the content.
  final double maxWidth;

  /// A page body.
  const FkPage({super.key, required this.children, this.maxWidth = 1240});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = FkWidth.of(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            width.padding,
            width.padding / 2,
            width.padding,
            width.padding * 2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A page header: title, subtitle, actions on the right (below on a phone).
class FkHeader extends StatelessWidget {
  /// Title, none when the app bar already shows it.
  final String? title;

  /// Subtitle.
  final String? subtitle;

  /// Trailing widget (a status pill).
  final Widget? badge;

  /// Actions.
  final List<Widget> actions;

  /// A page header.
  const FkHeader({
    super.key,
    this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    var text = Theme.of(context).textTheme;
    var t = context.festenao;
    var titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || badge != null)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (title != null) Text(title!, style: text.headlineSmall),
              ?badge,
            ],
          ),
        if (subtitle != null) ...[
          if (title != null || badge != null) const SizedBox(height: 4),
          Text(subtitle!, style: text.bodyMedium?.copyWith(color: t.ink2)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: FestenaoSpace.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.isEmpty) {
            return titles;
          }
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titles,
                const SizedBox(height: FestenaoSpace.l),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titles),
              const SizedBox(width: FestenaoSpace.l),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        },
      ),
    );
  }
}

/// A section title, uppercase monospace in the themes that want it.
class FkSectionTitle extends StatelessWidget {
  /// The title.
  final String title;

  /// A trailing action.
  final Widget? trailing;

  /// A section title.
  const FkSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.upperLabels ? title.toUpperCase() : title,
              style: t.labelStyle(context),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A card on the card colour with the line of the theme.
class FkCard extends StatelessWidget {
  /// Content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Tap.
  final VoidCallback? onTap;

  /// A card.
  const FkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FestenaoSpace.l),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radii.card),
        boxShadow: t.cardShadow,
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The meaning of a status pill.
enum FkStatus {
  /// Done, arrived.
  ok,

  /// To check.
  warn,

  /// Error, allergy.
  bad,

  /// Information.
  info,

  /// Neutral.
  muted,

  /// The accent (live, selected role).
  accent;

  /// Its colour in the tokens.
  Color color(FestenaoTokens t) => switch (this) {
    ok => t.ok,
    warn => t.warn,
    bad => t.bad,
    info => t.info,
    muted => t.muted,
    accent => t.accentText,
  };
}

/// A status pill: a word on the soft tint of its colour.
class FkStatusPill extends StatelessWidget {
  /// The words.
  final String label;

  /// The meaning.
  final FkStatus status;

  /// A leading dot (live).
  final bool dot;

  /// A status pill.
  const FkStatusPill(
    this.label, {
    super.key,
    this.status = FkStatus.muted,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var color = status.color(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.soft(status == FkStatus.accent ? t.accent : color),
        borderRadius: BorderRadius.circular(t.radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon on the soft tint of its colour.
class FkIconBox extends StatelessWidget {
  /// The icon.
  final IconData icon;

  /// Its colour, the accent by default.
  final Color? color;

  /// The box size.
  final double size;

  /// An icon box.
  const FkIconBox(this.icon, {super.key, this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var c = color ?? t.accentText;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.soft(color ?? t.accent),
        borderRadius: BorderRadius.circular(t.radii.control),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// Initials in a circle of a category colour.
class FkAvatar extends StatelessWidget {
  /// The name.
  final String name;

  /// The category index of the colour.
  final int category;

  /// Diameter.
  final double size;

  /// An avatar.
  const FkAvatar(this.name, {super.key, this.category = 0, this.size = 40});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var color = t.category(category);
    var initials = fkInitials(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.soft(color), shape: BoxShape.circle),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A number with its label and an optional progress.
class FkStatTile extends StatelessWidget {
  /// The label.
  final String label;

  /// The number.
  final String value;

  /// After the number (`/ 128`).
  final String? suffix;

  /// One line below.
  final String? detail;

  /// A progress from 0 to 1.
  final double? progress;

  /// The meaning of the number.
  final FkStatus status;

  /// An icon.
  final IconData icon;

  /// A stat tile.
  const FkStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.suffix,
    this.detail,
    this.progress,
    this.status = FkStatus.accent,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var color = status.color(t);
    return FkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.upperLabels ? label.toUpperCase() : label,
                  style: t.labelStyle(context),
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: text.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: text.titleMedium?.copyWith(color: t.ink3),
                  ),
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: color,
              ),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// A day and a time in a tile, the spine of a schedule.
class FkTimeTile extends StatelessWidget {
  /// The time (`19:00`).
  final String time;

  /// The day (`ven.`).
  final String day;

  /// Highlighted (live).
  final bool live;

  /// A time tile.
  const FkTimeTile({
    super.key,
    required this.time,
    required this.day,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: live ? t.accent : t.sunk,
        borderRadius: BorderRadius.circular(t.radii.control),
      ),
      child: Column(
        children: [
          Text(
            t.upperLabels ? day.toUpperCase() : day,
            style: text.labelSmall?.copyWith(
              color: live ? t.onAccent : t.ink2,
              fontFamily: t.monoLabels ? t.monoFamily : null,
            ),
          ),
          Text(
            time,
            style: text.titleMedium?.copyWith(
              color: live ? t.onAccent : t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid that turns its children into 1 to [maxColumns] columns.
class FkGrid extends StatelessWidget {
  /// The tiles.
  final List<Widget> children;

  /// The minimum width of a tile.
  final double minTileWidth;

  /// The maximum number of columns.
  final int maxColumns;

  /// A responsive grid.
  const FkGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.maxColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = FestenaoSpace.m;
        var columns = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        var width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Two panes side by side on a wide page, stacked on a narrow one.
class FkTwoPanes extends StatelessWidget {
  /// The main pane.
  final Widget main;

  /// The side pane (first on a narrow page when [sideFirst]).
  final Widget side;

  /// Flex of the main pane.
  final int mainFlex;

  /// Flex of the side pane.
  final int sideFlex;

  /// Side pane first when stacked.
  final bool sideFirst;

  /// Two panes.
  const FkTwoPanes({
    super.key,
    required this.main,
    required this.side,
    this.mainFlex = 3,
    this.sideFlex = 2,
    this.sideFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sideFirst
                ? [side, const SizedBox(height: FestenaoSpace.xl), main]
                : [main, const SizedBox(height: FestenaoSpace.xl), side],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: mainFlex, child: main),
            const SizedBox(width: FestenaoSpace.xl),
            Expanded(flex: sideFlex, child: side),
          ],
        );
      },
    );
  }
}

/// The initials of a name (`Camille Martin`: `CM`), of the local part of an
/// email (`camille.martin@x`: `CM`), or the first letter of an id.
String fkInitials(String name) {
  var text = name.trim();
  var at = text.indexOf('@');
  if (at > 0) {
    text = text.substring(0, at);
  }
  var parts = text
      .split(RegExp(r'[\s._-]+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  return parts.map((part) => part.characters.first.toUpperCase()).join();
}

/// A card holding rows separated by lines (members, settings).
class FkListCard extends StatelessWidget {
  /// The rows.
  final List<Widget> children;

  /// A list card.
  const FkListCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return FkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var (index, child) in children.indexed) ...[
            if (index > 0) Divider(color: t.line),
            child,
          ],
        ],
      ),
    );
  }
}

/// A row of a list card: a leading widget, a title, a subtitle, trailing
/// widgets; the trailing ones go under the subtitle on a narrow row.
class FkRow extends StatelessWidget {
  /// Leading (an avatar, an icon box).
  final Widget? leading;

  /// Title.
  final String title;

  /// A widget next to the title (a "you" tag).
  final Widget? titleTrailing;

  /// Subtitle.
  final String? subtitle;

  /// Trailing widgets (status pills).
  final List<Widget> badges;

  /// The last widget (a chevron, a menu), always on the right.
  final Widget? trailing;

  /// Tap.
  final VoidCallback? onTap;

  /// Width under which the badges go under the subtitle.
  final double narrowWidth;

  /// A list row.
  const FkRow({
    super.key,
    this.leading,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    this.badges = const [],
    this.trailing,
    this.onTap,
    this.narrowWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var narrow = constraints.maxWidth < narrowWidth;
          var badgeWrap = Wrap(spacing: 6, runSpacing: 6, children: badges);
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 4, 12),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: text.titleSmall),
                          ?titleTrailing,
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(color: t.ink2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (narrow && badges.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        badgeWrap,
                      ],
                    ],
                  ),
                ),
                if (!narrow && badges.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  badgeWrap,
                ],
                ?trailing,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// An empty state: an icon, a line, an optional action.
class FkEmpty extends StatelessWidget {
  /// The icon.
  final IconData icon;

  /// The line.
  final String message;

  /// An action under it.
  final Widget? action;

  /// An empty state.
  const FkEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          FkIconBox(icon, color: t.muted, size: 56),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: t.ink2),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
