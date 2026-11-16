/// The small dialogs and feedback of an app: [FestenaoMessageView] (an
/// empty list, an error), [festenaoShowSnack], [festenaoConfirmDialog],
/// [festenaoTextDialog] and [festenaoRunWithSnack] (an action with its error
/// in a snack bar).
///
/// The labels and the error text are parameters: an app binds its own
/// translations once (its `widget/async_view.dart`), the material *OK* and
/// *Cancel* labels otherwise.
library;

export 'src/app_dialogs/app_dialogs.dart';
