import 'package:festenao_admin_base_app/view/unsaved_changes_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Warns when leaving an edit screen that holds unsaved changes, with the
/// festenao unsaved changes dialog (save, discard, stay).
///
/// ```dart
/// class _EditState extends State<EditScreen>
///     with UnsavedChangesStateMixin<EditScreen> {
///   @override
///   bool get hasPendingChanges => _name.text != _initialName;
///
///   @override
///   Widget build(BuildContext context) =>
///       wrapUnsavedChanges(child: Scaffold(...));
/// }
/// ```
mixin UnsavedChangesStateMixin<T extends StatefulWidget> on State<T> {
  /// True when the screen holds changes not saved yet.
  bool get hasPendingChanges;

  /// Saves the changes and leaves the screen, offered by the dialog; null
  /// (the default) offers only to discard the changes or to stay.
  Future<void> Function()? get saveAndLeave => null;

  /// Wraps the screen to warn on back when [hasPendingChanges] is true.
  ///
  /// The pop is always intercepted: text controllers do not rebuild the
  /// screen on each keystroke, so a `canPop` flag computed at build time
  /// would be stale.
  Widget wrapUnsavedChanges({required Widget child}) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, Object? result) async {
        if (didPop) {
          return;
        }
        if (!hasPendingChanges) {
          Navigator.pop(context, result);
          return;
        }
        var save = saveAndLeave;
        var choice = await showUnsavedChangesDialog(
          context,
          canSave: save != null,
        );
        if (!mounted) {
          return;
        }
        switch (choice) {
          case UnsavedChangesDialogResult.save:
            await save!();
          case UnsavedChangesDialogResult.discard:
            Navigator.pop(context, result);
          case UnsavedChangesDialogResult.cancel || null:
            break;
        }
      },
      child: child,
    );
  }
}
