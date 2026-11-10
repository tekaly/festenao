// A kiosk screen with a hidden escape: the passcode keypad, then a menu to
// change the passcode or leave the kiosk screen.
import 'package:festenao_kiosk/festenao_kiosk.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(
    FestenaoKioskApp(
      // On Linux and Windows, pass the app's own factory (see the README):
      // sdbFactory: getSdbFactory(packageName: 'my_kiosk_app'),
      defaultPasscode: '2468',
      child: MaterialApp(
        routes: {
          ...festenaoKioskRoutes,
          '/': (_) => const KioskScreen(),
          '/admin': (_) => const AdminScreen(),
        },
      ),
    ),
  );
}

/// The screen visitors see.
class KioskScreen extends StatelessWidget {
  /// Constructor.
  const KioskScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Center(child: Text('Welcome', style: TextStyle(fontSize: 48))),
        Positioned(
          right: 0,
          bottom: 0,
          child: FestenaoKioskEscapeButton(
            onUnlocked: () => Navigator.of(context).pushNamed('/admin'),
          ),
        ),
      ],
    ),
  );
}

/// Reached only with the passcode.
class AdminScreen extends StatelessWidget {
  /// Constructor.
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Operator')),
    body: ListView(
      children: [
        ListTile(
          title: const Text('Change the passcode'),
          onTap: () =>
              Navigator.of(context).pushNamed(festenaoKioskSettingsRoute),
        ),
        ListTile(
          title: const Text('Back to the kiosk'),
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
