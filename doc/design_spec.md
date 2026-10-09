# Festenao design: a new theme and kit for the festenao apps (draft spec)

Draft, 2026-10-09, from the note: *improve the design of the festenao base
apps; the Poppins theme is an idea, but a new nice theme (good ideas in
tekartik firebase UI)*.

Notes the same day: the recent designs of playelio, buzzerelio
(neo-arcade) and cronelio (Obsidian Telemetry) were fine; create new themes
to try; the user access screens of the admin app are still ugly; every
festenao based app may look much alike, that is fine: **the UI must be
consistent everywhere, and responsive**.

Scope: the shared look of every festenao app (dashboard base app, admin base
app, base app, the apps built on them: the organisation module, the festival
apps, the quizz screens). Everything here is generic and public material: it can live in
the public festenao repo (no key, no personal data).

## 0. In short

1. **One theme builder** in `festenao_theme`: a seed colour, a scheme variant
   and a brightness give a finished theme, on a **neutral paper**, the seed
   kept for the action, the selection and the live state.
2. **Tokens derived from the theme**, as `AuthUiTheme` does in tekartik
   firebase UI: radii, spacing, soft tints, status and category colours, all
   computed from the colour scheme, so any seed looks finished.
3. **A shared kit** moved up from the *bp* app redesign (cards, link rows, section
   titles, stat tiles, empty states, search, filter chips, desk header, the
   phone and desk shell), so the base apps stop being debug screens.
4. **Poppins stays for headings**; body text, labels and figures get a face
   with tabular figures and arrows (proposed: Inter, bundled like Poppins).
5. **A theme gallery** in the dashboard demo, as in the firebase UI example,
   and before/after screenshots with the existing harnesses.
6. **One UI everywhere, responsive**: the same shell, kit and screen
   patterns in every festenao app (phone bottom bar, tablet rail, desk side
   panel), the apps differing by their preset and their modules.

**Built 2026-10-09** (phase 0, [§6](#6-status)): `festenao_theme`
`design.dart` with 13 presets and a gallery app with its screenshots.

## 1. What the base apps look like (captures of 2026-10-08)

From the captures of 2026-10-08 (`festenao/.local/2026-10-08-screenshot`):

- **Dashboard**: dark default, festenao blue seed. The project home is a text
  list of internal names (*Blog demo (legacy)*, *Ids from the route scope*,
  *Content (artist / location / event / image)*), shows ids to the user
  (*Local project ID*, *Firestore project id: uid: …*) and titles the screen
  with the project id (*Project festival_des_lumieres_2026*). Content lists
  are full width rows with raw dates (`2026-07-10`) and a trash icon on every
  row, a bright default FAB.
- **Admin app**: `themeData1()` without a font family, so Roboto where the
  other apps use Poppins. A route bar on the seed blue across the top
  (`/project/echappees_2026/event/…`), a grey placeholder drawer header,
  every form field stretched over 1 300 px, `Day(2026-07-17)` (a
  `CalendarDay.toString()`) in the date field, tags as text buttons.
- **Base app**: the form player and menus on `poppinsThemeData1`.

- **User access** (admin app and dashboard): the list titles each member
  with their user id and shows the Firestore path of the access collection;
  the edit form has a *User ID* field, a *Select an option <None>* dropdown,
  a free *Role* field and three independent switches (admin, editor,
  reader) although each includes the next; the share screen asks the level
  with three checkboxes, mixes French and English, centres oversized pill
  buttons and puts a trash icon on every pending invite.

Common to all: no hierarchy (titles and rows at close sizes), debug
information in user screens, the width unused, the seed tinting every
surface (the Material 3 default of `ColorScheme.fromSeed`).

## 2. What already works, elsewhere

| Source | What to take |
|---|---|
| tekartik `firebase_ui.dart`: `firebase_ui_auth` `AuthUiTheme` (`packages/firebase_ui_auth/lib/src/widget/auth_ui_theme.dart`) | Tokens **derived from the app `ThemeData`**: radii (20 card, 16 field), 56 px primary button, 520 px max content width, 20 px page padding, soft tints (`primarySoft`, `successSoft`, `warningSoft`, `infoSoft`, `dangerSoft`, `neutralSoft`) with an alpha per brightness, card and field colours, a border from `outlineVariant`, a primary tinted card shadow in light only, a page gradient and a primary gradient for the hero icon. Button text styles derived from `labelLarge` (no family-less styles). |
| The same repo, `example/ui_auth_emulator_example/lib/theme/example_theme.dart` | **Seed plus scheme variant** per theme (`DynamicSchemeVariant` tonalSpot, vibrant, fidelity, expressive, monochrome): Violet, Teal, Coral, Forest, Ocean, Graphite, each light and dark; one tap *next theme*, a swatch menu, an `AuthGalleryScreen` of scaled previews in nested navigators. |
| The *bp* app redesign (a private festival logistics app, the base of the organisation module) | A `ThemeExtension` of **meaningful tokens** (paper, surfaces 1 to 3, lines, ink 1 to 3, an accent with its ink, soft and text forms, status colours, category colours for the wristbands), two themes on the same tokens (*Basalte* dark for the evening, *Plein jour* light high contrast for the sun), about 25 kit widgets and a shell (bottom bar on the phone hubs, sidebar on the desk). |
| The *new_apps* redesign proposal (private demo apps, 2026-10-08, mockups only) | The diagnosis (seed tints everything, flat hierarchy, phone layouts on wide windows, fields with labels on the border) and six principles: paper and ink with one accent, time as the spine of schedules, readable at arm's length, big screens designed not scaled, one status language, use the width. Its token table (paper `#F3F4F6`, card white, sunk `#ECEEF1`, lines, ink `#16181D` / `#4E535E` / `#737885`, status ok `#1C7C45`, warn `#9A5B00`, bad `#C2302D`, info `#2459C2`, muted `#646A76`, six category colours, type 36 / 24 / 18 / 16 / 14 / 12.5, radii 24 / 16 / 12 / 8). Finding: Poppins has no tabular figures and no `→`. |
| buzzerelio neo-arcade (its app theme) | Near black panels, a yellow primary, a pink buzzer, green for live, heavy headings, uppercase JetBrains Mono labels, 14 px controls. Became the *Arcade* preset (with a light version). |
| cronelio Obsidian Telemetry (its admin app theme) | Obsidian surfaces in five steps, developer blue, green and amber status, tight 8 px controls, monospace data with tabular figures. Became the *Obsidian* preset (with a light version). |
| playelio (its app theme) | `poppinsThemeData1` with the lagoon seed `#009EE0`: the *Lagon* seed preset. |
| `festenao_theme` today | Poppins and JetBrains Mono bundled (offline, tests), `themeData1` (seeded scheme, floating snack bars on the seed, outlined inputs with the label always floating, large elevated buttons), the festenao blue. |

## 3. The proposal

### 3.1 Colour: paper, ink, one accent

- `ColorScheme.fromSeed(seed, variant, brightness)`, then the surface family
  replaced by **neutral** values: paper, card, sunk, lines, ink 1 to 3 (the
  new_apps light values; a neutral dark derived from the bp *Basalte*).
- The seed keeps `primary` and its containers: the main action, the
  selection, the live state, links. It never fills an app bar or a page.
- A **high contrast light** option (the bp *Plein jour*) for phones in the
  sun, next to light, dark and system.
- **Status**: five meanings (ok, warn, bad, info, muted), fixed colours per
  brightness, one pill shape. **Categories**: six colours given in sort
  order (stages, entity types, chart series), stable from phone to big
  screen.
- **Seeds**: a festenao default (the blue, or a new brand colour, open
  question) and the six presets of the firebase UI example with their
  variants, so an app or a festival picks a look in one line. Light seeds get
  a dark text colour on primary.

### 3.2 Tokens

`FestenaoTokens extends ThemeExtension`, built by the theme builder from the
scheme, never set by hand in an app:

| Group | Tokens |
|---|---|
| Surfaces | `paper`, `card`, `sunk`, `line`, `lineStrong`, `ink`, `ink2`, `ink3` |
| Accent | `accent`, `onAccent`, `accentSoft`, `accentText` (readable on paper) |
| Status | `ok`, `warn`, `bad`, `info`, `muted`, each with `…Soft` |
| Categories | `category(i)` and `categorySoft(i)` |
| Shape | radius sheet 24, card 16, control 12, pill 8 |
| Space | page padding 20 (phone) / 32 (desk), gap 8 / 12 / 16 / 24, max widths: form 640, reading 720, auth 520 |
| Depth | `cardShadow` (light only, accent tinted), `pageGradient`, `heroGradient` |

`AuthUiTheme` then reads these tokens instead of computing its own, so the
auth screens and the app match.

### 3.3 Type

- **Headings**: Poppins 600 (display, headline, title), the festenao identity.
- **Body, labels, figures**: a face with tabular figures and arrows. Proposed
  **Inter** (OFL), bundled in `festenao_theme` like Poppins, with `tnum` on
  times, counts and amounts. Alternative: Poppins everywhere and fixed digit
  cells (what the new_apps mockups did), at the cost of every number widget.
- **Code and raw data**: JetBrains Mono (`festenaoMonospaceFontFamily`).
- Scale 36 / 24 / 18 / 16 / 14 / 12.5, 16 px body, 48 px touch targets.
- No family-less `TextStyle` anywhere: every style derives from the theme's
  text theme (the screenshot harness gotcha, and the `AuthUiTheme` fix).
  The `festenaoPoppinsFontFamily` constant does not change.

### 3.4 Kit

Generic widgets moved up from the bp kit (renamed, on the tokens), in
`festenao_common_flutter` or a new `festenao_ui` package:

| Widget | From | Use |
|---|---|---|
| Card, list card, link row, section title, group header | `BpCard`, `BpListCard`, `BpLinkRow`, `BpSectionTitle`, `BpGroupHeader` | Menus and lists that read as content, not as debug rows |
| Page header, desk header, app bar title (title + subtitle) | `BpDeskHeader`, `BpAppBarTitle` | Names, never ids |
| Stat tile, key value | `BpStatTile`, `BpKeyValue` | Dashboards, detail pages |
| Search field, filter chip, filter bar | `BpSearchField`, `BpFilterChip`, `BpFilterBar` | Every list over ten items |
| Status pill, chip, icon box, avatar | `BpChip`, `BpIconBox`, `BpAvatar` | One status language |
| Empty state, loading, max width | `BpEmpty`, `BpLoading`, `BpMaxWidth` | No blank screens, no 1 300 px fields |
| Form layout and actions | `BpFormActions` + the unsaved changes mixin | Labels above fields, two columns on desk, save in an action bar |
| Shell | `BpProjectShell` | Bottom bar (phone), rail (medium), sidebar with the app identity (desk), driven by the project's modules |

The orga specific pieces stay in orga: tickets, stamps, planning cells,
wristband colours (on the category colours), the meal and night tokens (as
named aliases of accent and category tokens).

### 3.5 Screens

- Users never see ids, route strings or debug labels: those move to the
  debug screen (the admin route bar included).
- Titles show the project and record **names**.
- Dates and times formatted in French (`ven. 10 juil.`, `20:30`), schedules
  on a time column with a now line (new_apps principle 2).
- Lists: leading thumbnail or date tile, title, one line of detail, actions
  in the detail page or a menu, not a trash icon per row.
- The project home: one card per module (enabled by the project's modules),
  with a count or a state, instead of a text list.
- Forms: labels above fields, a 640 px column, short fields side by side on
  desk, tags as selectable chips, the date field shows a formatted date.

### 3.6 Gallery and checks

- A **theme gallery** screen in the dashboard demo (the firebase UI
  `AuthGalleryScreen` idea): the presets in light, dark and high contrast,
  with the kit and a few real screens scaled side by side.
- Before and after captures with the screenshot harnesses and the dashboard
  demo harness; the screenshot utilities move to a public `lib/` first.

## 4. Phases

| # | Phase | Content |
|---|---|---|
| 0 | **Theme and tokens** | `festenaoThemeData(seed, variant, brightness, contrast)` and `FestenaoTokens` in `festenao_theme`, Inter bundled if chosen, the presets, the gallery in the dashboard demo. `themeData1` stays for the apps not yet moved. |
| 1 | **Kit** | The generic bp widgets moved up on the tokens, with widget tests and gallery entries. `AuthUiTheme` reading the tokens. |
| 2 | **Dashboard base app** | Shell, project home by module, names not ids, content lists and forms on the kit. |
| 3 | **Admin base app** | The same theme (Poppins and Inter, not Roboto), the route bar to debug, forms and the date field. |
| 4 | **Apps** | The organisation module (the *bp* app): its token extension becomes aliases on `FestenaoTokens`, Basalte and Plein jour become the festenao dark and high contrast light. Then each festenao app picks a seed; a festival seed stored on the project later. |

## 5. Open questions

1. Inter (or another face with tabular figures) for body and figures, or
   Poppins everywhere with fixed digit cells?
2. The festenao brand seed: keep the blue, or a new colour (the firebase UI
   reference is violet `#5B4FE9`)?
3. Dark or light by default for the dashboard (dark today; the bp app picks
   by time of day on phones)?
4. Package for the kit: `festenao_common_flutter` or a new `festenao_ui`, and
   the widget prefix (`Festenao…`, shorter)?
5. A seed per festival on the project, set by the organizer, from phase 4?

## 6. Status

Built on 2026-10-09 in `tekaly/festenao` (`packages_flutter/festenao_theme`),
public material only:

- `lib/design.dart`: `FestenaoPalette` (`fromSeed` on the neutral paper),
  `festenaoThemeDataFromPalette` (every component themed from the palette,
  no seed tint on surfaces), `FestenaoTokens` (`context.festenao`: colours,
  soft tints, radii, card shadow, hero gradient, label style),
  `FestenaoThemePreset` and 13 presets:
  - hand made, light and dark: **Festenao** (neutral, blue), **Basalte ·
    Plein jour** (bp), **Arcade** (buzzerelio, plus a light version),
    **Obsidian** (cronelio, plus a light version), **Guinguette** (new:
    terracotta and teal on cream), **Nocturne** (new: magenta and violet on
    deep indigo);
  - seeds on the neutral paper: Violet, Teal, Coral, Forest, Ocean,
    Graphite (the firebase UI presets and variants), Lagon (playelio).
- `test/design_test.dart`: every preset in both brightnesses builds with its
  tokens, every text style has a family, and the contrast holds (ink on
  paper 7:1, secondary ink 4.5:1, status and accent text 3:1, button label
  on the accent 4.5:1).
- `example/`: the gallery app (`flutter run -d linux`): a festival day, a
  redesigned **access page** (one role per person as a segmented choice
  with what it allows, names and emails instead of ids, role pills, pending
  invites with their status, email and link invites in one card) and the
  kit; bottom bar, rail or side panel by width; the preset menu, *next
  theme* and light/dark in the app bar. `test/gallery_test.dart` runs every
  page at phone, tablet and desk sizes. `tool/screenshot_test.dart` shoots
  130 pngs (13 presets, light and dark, 3 desk pages, 2 phone pages) into
  `.local/themes`, `tool/contact_sheet.py` builds side by side sheets and an
  `index.html`.
- **Kit** (phase 1, 2026-10-09): `package:festenao_theme/kit.dart`, prefix
  `Fk` (open question 4): `FkPage`, `FkHeader`, `FkSectionTitle`, `FkCard`,
  `FkListCard`, `FkRow`, `FkStatusPill`, `FkIconBox`, `FkAvatar`
  (`fkInitials`), `FkStatTile`, `FkTimeTile`, `FkGrid`, `FkTwoPanes`,
  `FkEmpty`; `test/kit_test.dart`. The gallery uses it.
- **Admin access screens** rebuilt on the kit (2026-10-09): the project
  members and the app users (`AdminAccessMembersView`: search, name and
  email instead of ids, avatar, role pill, *you*, empty states, the
  Firestore path as a discreet note in debug builds only), the user page
  (profile card, *Edit* and *Copy the ID*, account card, raw data folded),
  the edit form shared by project and app users (Account, Role as one
  Reader / Editor / Admin choice with what it allows, Advanced for the app
  role); strings in English and French. The admin app now runs on the
  *Festenao* dark preset, its route path bar shows in debug builds only
  (`festenaoAdminAppShowPathBar`), the drawer opens on a brand row.
  `festenao_admin_base_app/test/access_view_test.dart`.
- Not done: Inter (open question 1), the dashboard base app on the presets
  and the kit (phase 2), the other admin screens (lists and forms of the
  content: phase 3), the drawer items.

## Sources

- `tekaly/festenao` at fdd5fdd: `packages_flutter/festenao_theme` (the
  presets and the gallery), `festenao_admin_base_app/lib/run.dart`
  (`themeData1()`), the captures in `.local/2026-10-08-screenshot`.
- `tekartik/firebase_ui.dart`: `AuthUiTheme`, the example themes and gallery,
  captures in `.local/2026-10-08`.
- The private sources (the *bp* app, the *new_apps* proposal, the app themes
  of buzzerelio, cronelio and playelio, the organisation module plan) are
  listed in the owner's private notes.
