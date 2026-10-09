import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:festenao_theme_example/src/gallery_app.dart';
import 'package:festenao_theme_example/src/gallery_shell.dart';
import 'package:material_ui/material_ui.dart';

/// The palette, the type and the components of the current preset.
class FkPageView extends StatelessWidget {
  /// The kit page.
  const FkPageView({super.key});

  @override
  Widget build(BuildContext context) {
    var controller = GalleryScope.of(context);
    var state = controller.value;
    return FkPage(
      children: [
        FkHeader(title: state.preset.name, subtitle: state.preset.description),
        const FkSectionTitle('Thèmes'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var preset in festenaoThemePresets)
              ChoiceChip(
                avatar: PresetSwatch(
                  preset: preset,
                  brightness: state.brightness,
                  size: 20,
                ),
                label: Text(preset.name),
                selected: preset == state.preset,
                showCheckmark: false,
                onSelected: (_) => controller.selectPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: FestenaoSpace.xl),
        const FkTwoPanes(
          mainFlex: 1,
          sideFlex: 1,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FkSectionTitle('Palette'),
              _PaletteCard(),
              SizedBox(height: FestenaoSpace.xl),
              FkSectionTitle('Texte'),
              _TypeCard(),
            ],
          ),
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [FkSectionTitle('Composants'), _ComponentsCard()],
          ),
        ),
      ],
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard();

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    Widget group(String title, List<(String, Color)> colors) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var (name, color) in colors)
                _Swatch(name: name, color: color),
            ],
          ),
        ],
      ),
    );
    return FkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group('Surfaces', [
            ('paper', t.paper),
            ('card', t.card),
            ('sunk', t.sunk),
            ('line', t.line),
            ('ink', t.ink),
            ('ink 2', t.ink2),
          ]),
          group('Accent', [
            ('accent', t.accent),
            ('text', t.accentText),
            ('soft', Color.alphaBlend(t.accentSoft, t.card)),
            ('second', t.secondary),
          ]),
          group('Statuts', [
            ('ok', t.ok),
            ('warn', t.warn),
            ('bad', t.bad),
            ('info', t.info),
            ('muted', t.muted),
          ]),
          group('Catégories', [
            for (var i = 0; i < 6; i++) ('c${i + 1}', t.category(i)),
          ]),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;

  const _Swatch({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(t.radii.control),
              border: Border.all(color: t.line),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard();

  @override
  Widget build(BuildContext context) {
    var text = Theme.of(context).textTheme;
    var t = context.festenao;
    return FkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Les Tilleuls', style: text.displaySmall),
          Text('Programme du vendredi', style: text.headlineSmall),
          const SizedBox(height: 4),
          Text('Fanfare Les Cuivrés, place du marché', style: text.titleLarge),
          Text('Déambulation, deux passages', style: text.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Les repas des compagnies suivent leurs spectacles : '
            'un spectacle à midi loin de la cantine devient un panier repas.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text('Mis à jour il y a 2 min', style: text.bodySmall),
          const SizedBox(height: 8),
          Text(
            t.upperLabels ? 'ÉTIQUETTE DE SECTION' : 'Étiquette de section',
            style: t.labelStyle(context),
          ),
          Text(
            '12:42 · 96 / 128 · 2 450,00 €',
            style: text.titleMedium?.copyWith(fontFamily: t.monoFamily),
          ),
        ],
      ),
    );
  }
}

class _ComponentsCard extends StatefulWidget {
  const _ComponentsCard();

  @override
  State<_ComponentsCard> createState() => _ComponentsCardState();
}

class _ComponentsCardState extends State<_ComponentsCard> {
  var _service = 'midi';
  var _tags = <String>{'Végétarien'};
  var _notify = true;
  var _checked = true;
  var _guests = 0.4;

  @override
  Widget build(BuildContext context) {
    var text = Theme.of(context).textTheme;
    return FkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Enregistrer')),
              OutlinedButton(onPressed: () {}, child: const Text('Annuler')),
              TextButton(onPressed: () {}, child: const Text('Plus tard')),
              const FilledButton(onPressed: null, child: Text('Désactivé')),
            ],
          ),
          const SizedBox(height: 20),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Nom',
              helperText: 'Tel qu\'il apparaît sur la liste de la cantine',
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Téléphone',
              errorText: 'Un numéro à 10 chiffres',
            ),
          ),
          const SizedBox(height: 18),
          Text('Service', style: text.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'midi', label: Text('Midi')),
              ButtonSegment(value: 'soir', label: Text('Soir')),
              ButtonSegment(value: 'panier', label: Text('Panier')),
            ],
            selected: {_service},
            onSelectionChanged: (value) =>
                setState(() => _service = value.first),
          ),
          const SizedBox(height: 18),
          Text('Régimes', style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var tag in ['Végétarien', 'Sans gluten', 'Halal', 'Vegan'])
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (selected) => setState(() {
                    _tags = {..._tags};
                    selected ? _tags.add(tag) : _tags.remove(tag);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prévenir par email'),
            subtitle: const Text('À chaque changement de créneau'),
            value: _notify,
            onChanged: (value) => setState(() => _notify = value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Repas pointé'),
            value: _checked,
            onChanged: (value) => setState(() => _checked = value ?? false),
          ),
          Slider(value: _guests, onChanged: (v) => setState(() => _guests = v)),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FkStatusPill('Arrivé', status: FkStatus.ok),
              FkStatusPill('À vérifier', status: FkStatus.warn),
              FkStatusPill('Allergie', status: FkStatus.bad),
              FkStatusPill('Info', status: FkStatus.info),
              FkStatusPill('Brouillon'),
              FkStatusPill('En direct', status: FkStatus.accent, dot: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Retirer du repas ?'),
                      content: const Text(
                        'La présence de Lina Moreau au déjeuner sera supprimée.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Retirer'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Dialogue'),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: () {},
                child: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
