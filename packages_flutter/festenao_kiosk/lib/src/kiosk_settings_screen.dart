import 'package:material_ui/material_ui.dart';

import 'kiosk_app.dart';
import 'kiosk_controller.dart';

/// Kiosk settings screen: lets the operator configure the escape
/// passcode. It shows the code in effect and saves only exactly
/// [FestenaoKioskController.passcodeLength] digits. It is not protected by
/// itself: open it after [FestenaoKioskController.checkPasscode].
///
/// Push it directly (`Navigator.push`), via
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

  /// Shown under the field when the entered passcode is refused.
  String? _error;

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
    var controller = FestenaoKioskApp.of(context);
    await controller.ready;
    // Closed meanwhile: the text controller is disposed.
    if (!mounted) {
      return;
    }
    // The code in effect (the default one until a passcode is saved), so
    // that saving the untouched field keeps it.
    _passcodeController.text = controller.passcode;
    setState(() => _loaded = true);
  }

  /// Saves the entered passcode, only when it is exactly
  /// [FestenaoKioskController.passcodeLength] digits (the code the keypad
  /// asks for).
  Future<void> _save(FestenaoKioskController controller) async {
    var length = controller.passcodeLength;
    var text = _passcodeController.text.trim();
    if (!RegExp('^[0-9]{$length}\$').hasMatch(text)) {
      setState(() => _error = 'Enter exactly $length digits');
      return;
    }
    await controller.setPasscode(text);
    if (mounted) {
      Navigator.of(context).pop();
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
                      errorText: _error,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: !_loaded ? null : () => _save(controller),
        child: const Icon(Icons.check),
      ),
    );
  }
}
