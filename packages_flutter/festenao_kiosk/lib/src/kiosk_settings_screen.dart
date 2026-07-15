import 'package:flutter/material.dart';

import 'kiosk_app.dart';

/// Kiosk settings screen: lets the operator configure the escape
/// passcode. Push it directly (`Navigator.push`), via
/// `FestenaoKioskController.goToSettings`, or wire it into your own
/// router (go_router, Navigator 2.0, ...) using `festenaoKioskSettingsRoute`
/// as the path.
class FestenaoKioskSettingsScreen extends StatefulWidget {
  /// Creates a [FestenaoKioskSettingsScreen].
  const FestenaoKioskSettingsScreen({super.key});

  @override
  State<FestenaoKioskSettingsScreen> createState() =>
      _FestenaoKioskSettingsScreenState();
}

class _FestenaoKioskSettingsScreenState
    extends State<FestenaoKioskSettingsScreen> {
  final _passcodeController = TextEditingController();
  var _loaded = false;
  var _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FestenaoKioskApp.of(context) depends on an InheritedWidget, which
    // can't be looked up from initState — didChangeDependencies is the
    // first safe place to kick this off, and it only needs to run once.
    if (!_loading) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    // ignore: avoid_print
    print('DEBUG _load start');
    var controller = FestenaoKioskApp.of(context);
    // ignore: avoid_print
    print('DEBUG got controller, awaiting ready');
    await controller.ready;
    // ignore: avoid_print
    print('DEBUG ready awaited');
    _passcodeController.text = controller.passcodeOrNull ?? '';
    if (mounted) {
      // ignore: avoid_print
      print('DEBUG mounted, calling setState');
      setState(() => _loaded = true);
    } else {
      // ignore: avoid_print
      print('DEBUG NOT mounted');
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var controller = FestenaoKioskApp.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kiosk settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _passcodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      label: Text(
                        'Passcode (${controller.passcodeLength} digits)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: !_loaded
            ? null
            : () async {
                await controller.setPasscode(_passcodeController.text);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
        child: const Icon(Icons.check),
      ),
    );
  }
}
