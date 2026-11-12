import 'package:festenao_common/api/festenao_api_app_status.dart';
import 'package:material_ui/material_ui.dart';

/// Semantics ids of the gate (tests, app agents).
abstract final class FestenaoAppStatusUiIds {
  /// The maintenance screen.
  static const maintenance = 'app_status_maintenance';

  /// The read only banner.
  static const readOnlyBanner = 'app_status_read_only';

  /// The button an app admin goes on with in maintenance.
  static const bypass = 'app_status_bypass';
}

/// The texts of the gate, French or English by the locale.
class _Texts {
  final bool fr;

  _Texts(BuildContext context)
    : fr = Localizations.maybeLocaleOf(context)?.languageCode == 'fr';

  String get maintenanceTitle =>
      fr ? 'Maintenance en cours' : 'Under maintenance';

  String get maintenanceBody => fr
      ? 'Le service est momentanément indisponible. Merci de réessayer '
            'plus tard.'
      : 'The service is unavailable for now. Please try again later.';

  String get readOnly => fr
      ? 'Lecture seule : les modifications sont désactivées pour le moment.'
      : 'Read only: changes are turned off for now.';

  String until(String when) => fr ? 'Retour prévu : $when' : 'Back: $when';

  String get bypass =>
      fr ? 'Continuer (administrateur)' : 'Continue (administrator)';
}

String _formatUntil(DateTime until) {
  var local = until.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Shows [child] as the status of the app allows ([status], normal until it
/// emits and when null): in maintenance a full screen message instead, in
/// read only a banner above it.
///
/// Placed in `MaterialApp.builder` (around the navigator): every screen is
/// covered. In read only the app keeps its state below (the navigator of
/// `MaterialApp` has a global key); the maintenance screen replaces it, so
/// the app below is disposed and starts again from its initial route (its
/// navigation stack and screen states lost) once the maintenance is over or
/// bypassed. [canBypass] (an app admin) adds
/// a button going on to the app in maintenance; the server serves the app
/// admins anyway.
class FestenaoAppStatusGate extends StatefulWidget {
  /// The status the app runs with ([festenaoAppStatusOnSnapshot]).
  final Stream<FestenaoAppStatus>? status;

  /// True to offer going on in maintenance.
  final bool canBypass;

  /// The app.
  final Widget child;

  /// The gate.
  const FestenaoAppStatusGate({
    super.key,
    required this.status,
    required this.child,
    this.canBypass = false,
  });

  @override
  State<FestenaoAppStatusGate> createState() => _FestenaoAppStatusGateState();
}

class _FestenaoAppStatusGateState extends State<FestenaoAppStatusGate> {
  var _bypassed = false;

  @override
  Widget build(BuildContext context) {
    var status = widget.status;
    if (status == null) {
      return widget.child;
    }
    return StreamBuilder<FestenaoAppStatus>(
      stream: status,
      initialData: FestenaoAppStatus.normal,
      builder: (context, snapshot) {
        var status = snapshot.data ?? FestenaoAppStatus.normal;
        if (status.isMaintenance && !_bypassed) {
          return FestenaoAppMaintenanceScreen(
            status: status,
            onBypass: widget.canBypass
                ? () => setState(() => _bypassed = true)
                : null,
          );
        }
        if (status.isNormal) {
          // A new maintenance shows the screen again.
          _bypassed = false;
          return widget.child;
        }
        // Read only, or maintenance bypassed by an admin.
        return Column(
          children: [
            FestenaoAppStatusBanner(status: status),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The maintenance screen: the message of the status and when it should
/// end; [onBypass] adds a button going on (an app admin).
class FestenaoAppMaintenanceScreen extends StatelessWidget {
  /// The status.
  final FestenaoAppStatus status;

  /// Going on, no button when null.
  final VoidCallback? onBypass;

  /// The screen.
  const FestenaoAppMaintenanceScreen({
    super.key,
    required this.status,
    this.onBypass,
  });

  @override
  Widget build(BuildContext context) {
    var texts = _Texts(context);
    var theme = Theme.of(context);
    var message = status.messageFor(
      Localizations.maybeLocaleOf(context)?.languageCode,
    );
    var until = status.until;
    return Semantics(
      identifier: FestenaoAppStatusUiIds.maintenance,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.construction,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      texts.maintenanceTitle,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message ?? texts.maintenanceBody,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (until != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        texts.until(_formatUntil(until)),
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (onBypass case var onBypass?) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        identifier: FestenaoAppStatusUiIds.bypass,
                        child: OutlinedButton(
                          onPressed: onBypass,
                          child: Text(texts.bypass),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The banner of a status that is not normal (read only, or maintenance
/// once bypassed): its message or the default one.
class FestenaoAppStatusBanner extends StatelessWidget {
  /// The status.
  final FestenaoAppStatus status;

  /// The banner.
  const FestenaoAppStatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    var texts = _Texts(context);
    var colorScheme = Theme.of(context).colorScheme;
    var message = status.messageFor(
      Localizations.maybeLocaleOf(context)?.languageCode,
    );
    var title = status.isMaintenance ? texts.maintenanceTitle : texts.readOnly;
    return Semantics(
      identifier: FestenaoAppStatusUiIds.readOnlyBanner,
      child: Material(
        color: colorScheme.tertiaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  status.isMaintenance ? Icons.construction : Icons.lock_clock,
                  color: colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message == null ? title : '$title $message',
                    style: TextStyle(color: colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
