import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_admin_app/l10n/app_intl.dart';

enum UnsavedChangesDialogResult { save, discard, cancel }

/// Shows a dialog and resolves to true when the user has indicated that they
/// want to pop.
///
/// A return value of null indicates a desire not to pop, such as when the
/// user has dismissed the modal without tapping a button.
///
/// [canSave] false hides the save button, for a screen that cannot save from
/// the dialog (the user then discards or stays).
Future<UnsavedChangesDialogResult?> showUnsavedChangesDialog(
  BuildContext context, {
  bool canSave = true,
}) async {
  var intl = appIntl(context);
  var festenaoIntl = festenaoAdminAppIntl(context);
  return await showDialog<UnsavedChangesDialogResult>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(intl.editUnsavedChangesTitle),
            content: Text(
              canSave
                  ? intl.editYouHaveUnsavedChanges
                  : festenaoIntl.editLeaveWithoutSaving,
            ),
            actions: <Widget>[
              if (canSave)
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: Text(intl.editSaveChanges),
                  onPressed: () {
                    Navigator.pop(context, UnsavedChangesDialogResult.save);
                  },
                ),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(intl.editDiscardChanges),
                onPressed: () {
                  Navigator.pop(context, UnsavedChangesDialogResult.discard);
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(intl.cancelButtonLabel),
                onPressed: () {
                  Navigator.pop(context, UnsavedChangesDialogResult.cancel);
                },
              ),
            ],
          );
        },
      ) ??
      UnsavedChangesDialogResult.cancel;
}
