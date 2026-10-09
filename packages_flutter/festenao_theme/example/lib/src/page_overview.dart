import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/kit.dart';
import 'package:material_ui/material_ui.dart';

/// A festival day: what is live, the counts, the modules, tonight.
class OverviewPage extends StatelessWidget {
  /// The overview.
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return KitPage(
      children: [
        KitHeader(
          title: 'Festival des Tilleuls 2026',
          subtitle: 'Vendredi 3 juillet · jour 4 sur 5',
          badge: const KitStatusPill(
            'Déjeuner en cours',
            status: KitStatus.ok,
            dot: true,
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Pointer'),
            ),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Repas de Lina Moreau pointé à 12:42'),
                  action: SnackBarAction(label: 'Annuler', onPressed: () {}),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const KitGrid(
          minTileWidth: 200,
          children: [
            KitStatTile(
              label: 'Couverts midi',
              value: '96',
              suffix: '/ 128',
              icon: Icons.restaurant_rounded,
              progress: 0.75,
              detail: '32 encore attendus',
            ),
            KitStatTile(
              label: 'Arrivées',
              value: '12',
              icon: Icons.luggage_rounded,
              status: KitStatus.info,
              detail: 'dont 3 après 22:00',
            ),
            KitStatTile(
              label: 'Créneaux',
              value: '3',
              suffix: 'à pourvoir',
              icon: Icons.schedule_rounded,
              status: KitStatus.warn,
              detail: 'Bar ce soir, parking demain',
            ),
            KitStatTile(
              label: 'Allergies',
              value: '7',
              icon: Icons.warning_amber_rounded,
              status: KitStatus.bad,
              detail: 'Arachide, gluten, lactose',
            ),
          ],
        ),
        const SizedBox(height: FestenaoSpace.xl),
        KitTwoPanes(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KitSectionTitle('Modules'),
              KitGrid(
                minTileWidth: 230,
                maxColumns: 3,
                children: [
                  for (var (index, module) in _modules.indexed)
                    _ModuleCard(module: module, category: index),
                ],
              ),
            ],
          ),
          side: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [KitSectionTitle('Ce soir sur scène'), _ShowsCard()],
          ),
        ),
      ],
    );
  }
}

class _Module {
  final String title;
  final String detail;
  final IconData icon;
  final String count;

  const _Module(this.title, this.detail, this.icon, this.count);
}

const _modules = [
  _Module(
    'Repas',
    'Services, pointage, régimes',
    Icons.restaurant_rounded,
    '10',
  ),
  _Module('Nuits', 'Hébergements, chambres', Icons.bedtime_rounded, '4'),
  _Module('Équipe', 'Bénévoles, statuts', Icons.groups_rounded, '86'),
  _Module('Créneaux', 'Postes et planning', Icons.view_week_rounded, '42'),
  _Module(
    'Programme',
    'Spectacles et lieux',
    Icons.theater_comedy_rounded,
    '18',
  ),
  _Module('Rapports', 'Cuisine, facturation', Icons.bar_chart_rounded, ''),
];

class _ModuleCard extends StatelessWidget {
  final _Module module;
  final int category;

  const _ModuleCard({required this.module, required this.category});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return KitCard(
      onTap: () {},
      child: Row(
        children: [
          KitIconBox(module.icon, color: t.category(category), size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  module.detail,
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (module.count.isNotEmpty)
            Text(
              module.count,
              style: text.titleMedium?.copyWith(
                color: t.ink2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: t.ink3),
        ],
      ),
    );
  }
}

class _Show {
  final String time;
  final String title;
  final String place;
  final int category;
  final String status;
  final KitStatus kind;
  final bool live;

  const _Show(
    this.time,
    this.title,
    this.place,
    this.category,
    this.status,
    this.kind, {
    this.live = false,
  });
}

const _shows = [
  _Show(
    '18:30',
    'Fanfare Les Cuivrés',
    'Place du marché',
    0,
    'En cours',
    KitStatus.ok,
    live: true,
  ),
  _Show(
    '19:15',
    'Cie Les Échasses Bleues',
    'Rue haute',
    1,
    'À l\'heure',
    KitStatus.muted,
  ),
  _Show(
    '20:30',
    'Théâtre du Pont-Levis',
    'Grande scène',
    2,
    'Retard 15 min',
    KitStatus.warn,
  ),
  _Show('21:45', 'Cirque Opale', 'Chapiteau', 3, 'À l\'heure', KitStatus.muted),
  _Show(
    '23:00',
    'Collectif Fil Rouge',
    'Cour du lycée',
    4,
    'Annulé',
    KitStatus.bad,
  ),
];

class _ShowsCard extends StatelessWidget {
  const _ShowsCard();

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return KitCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var (index, show) in _shows.indexed) ...[
            if (index > 0) Divider(indent: 16, endIndent: 16, color: t.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  KitTimeTile(time: show.time, day: 'ven.', live: show.live),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.title,
                          style: text.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: t.category(show.category),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                show.place,
                                style: text.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  KitStatusPill(show.status, status: show.kind, dot: show.live),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
