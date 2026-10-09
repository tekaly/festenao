import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/kit.dart';
import 'package:material_ui/material_ui.dart';

/// The access of a project as the design spec proposes it: one role per
/// person (reader, editor, admin, each including the one before), people
/// shown by name and email, never by id, invites by email or by link in one
/// card, pending invites with their status.
class AccessPage extends StatelessWidget {
  /// The access page.
  const AccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return KitPage(
      maxWidth: 1180,
      children: [
        KitHeader(
          title: 'Accès',
          subtitle: 'Qui peut ouvrir et modifier Festival des Tilleuls 2026',
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Quitter le festival'),
            ),
          ],
        ),
        const KitTwoPanes(
          sideFirst: true,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KitSectionTitle('Membres · 5'),
              _MembersCard(),
              SizedBox(height: FestenaoSpace.xl),
              KitSectionTitle('Invitations en attente · 2'),
              _PendingCard(),
            ],
          ),
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [KitSectionTitle('Inviter'), _InviteCard()],
          ),
        ),
      ],
    );
  }
}

/// A role and what it allows.
enum _Role {
  reader('Lecteur', 'Consulte les listes et les rapports', KitStatus.muted),
  editor('Éditeur', 'Pointe et modifie les données', KitStatus.info),
  admin('Admin', 'Gère aussi les accès et le festival', KitStatus.accent);

  final String label;
  final String detail;
  final KitStatus status;

  const _Role(this.label, this.detail, this.status);
}

class _Member {
  final String name;
  final String email;
  final _Role role;
  final bool me;
  final String seen;

  const _Member(this.name, this.email, this.role, this.seen, {this.me = false});
}

const _members = [
  _Member(
    'Inès Dubois',
    'ines@tilleuls-demo.test',
    _Role.admin,
    'en ligne',
    me: true,
  ),
  _Member('Alex Martin', 'alex@tilleuls-demo.test', _Role.admin, 'hier'),
  _Member(
    'Camille Roux',
    'camille@tilleuls-demo.test',
    _Role.editor,
    'il y a 2 h',
  ),
  _Member('Hugo Bernard', 'hugo@tilleuls-demo.test', _Role.editor, 'lundi'),
  _Member('Cuisine', 'cuisine@tilleuls-demo.test', _Role.reader, 'ce matin'),
];

class _MembersCard extends StatelessWidget {
  const _MembersCard();

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un membre',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          for (var (index, member) in _members.indexed) ...[
            Divider(color: t.line),
            _MemberRow(member: member, category: index),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final _Member member;
  final int category;

  const _MemberRow({required this.member, required this.category});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var pill = KitStatusPill(member.role.label, status: member.role.status);
    return InkWell(
      onTap: () {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On a phone the role goes under the email.
          var narrow = constraints.maxWidth < 440;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              children: [
                KitAvatar(member.name, category: category),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(member.name, style: text.titleSmall),
                          if (member.me)
                            Text(
                              'vous',
                              style: text.labelMedium?.copyWith(color: t.ink3),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        narrow
                            ? member.email
                            : '${member.email} · ${member.seen}',
                        style: text.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (narrow) ...[const SizedBox(height: 6), pill],
                    ],
                  ),
                ),
                if (!narrow) ...[const SizedBox(width: 8), pill],
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: Icon(Icons.more_vert_rounded, color: t.ink3),
                  itemBuilder: (context) => [
                    for (var role in _Role.values)
                      CheckedPopupMenuItem(
                        value: role.name,
                        checked: role == member.role,
                        child: Text(role.label),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Retirer l\'accès',
                        style: TextStyle(color: t.bad),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard();

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    Widget row(String email, _Role role, String sent) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          KitIconBox(Icons.mail_outline_rounded, color: t.warn),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const KitStatusPill('En attente', status: KitStatus.warn),
                    Text(
                      '${role.label} · envoyée $sent',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Renvoyer',
            onPressed: () {},
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          row('paul.leroy@tilleuls-demo.test', _Role.reader, 'hier'),
          Divider(color: t.line),
          row('jeanne.roux@tilleuls-demo.test', _Role.editor, 'il y a 3 jours'),
        ],
      ),
    );
  }
}

class _InviteCard extends StatefulWidget {
  const _InviteCard();

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  var _role = _Role.editor;

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return KitCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rôle', style: text.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<_Role>(
            showSelectedIcon: false,
            segments: [
              for (var role in _Role.values)
                ButtonSegment(value: role, label: Text(role.label)),
            ],
            selected: {_role},
            onSelectionChanged: (selection) =>
                setState(() => _role = selection.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: t.ink3),
              const SizedBox(width: 6),
              Expanded(child: Text(_role.detail, style: text.bodySmall)),
            ],
          ),
          const SizedBox(height: 20),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Adresse email',
              hintText: 'prenom.nom@exemple.fr',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.send_rounded),
            label: const Text('Envoyer l\'invitation'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: t.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: text.bodySmall),
              ),
              Expanded(child: Divider(color: t.line)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: t.sunk,
              borderRadius: BorderRadius.circular(t.radii.control),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: t.ink2, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'tilleuls.festenao.app/i/7KQ-2MX',
                    style: text.bodyMedium?.copyWith(
                      fontFamily: t.monoFamily,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copier le lien',
                  onPressed: () {},
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lien valable 7 jours, rôle ${_role.label.toLowerCase()}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
