import 'package:flutter/material.dart';
import 'package:tkcms_admin_app/l10n/app_intl.dart';

enum UnsavedChangesDialogResult { save, discard, cancel }

/// Shows a dialog and resolves to true when the user has indicated that they
/// want to pop.
///
/// A return value of null indicates a desire not to pop, such as when the
/// user has dismissed the modal without tapping a button.
Future<UnsavedChangesDialogResult?> showUnsavedChangesDialog(
  BuildContext context,
) async {
  var intl = appIntl(context);
  return await showDialog<UnsavedChangesDialogResult>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(intl.editUnsavedChangesTitle),
            content: Text(intl.editYouHaveUnsavedChanges),
            actions: <Widget>[
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
