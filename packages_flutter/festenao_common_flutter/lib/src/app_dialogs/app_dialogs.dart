import 'package:material_ui/material_ui.dart';

/// A centered message with an icon, and an optional action below (an empty
/// list, an error).
class FestenaoMessageView extends StatelessWidget {
  /// The icon, above the message.
  final IconData icon;

  /// The message.
  final String message;

  /// An optional action below the message (a button).
  final Widget? action;

  /// A centered [message] under [icon], with [action] below when given.
  const FestenaoMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// Shows [message] in a snack bar, replacing the current one; nothing when
/// [context] has no [ScaffoldMessenger].
void festenaoShowSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks a yes/no question titled [title] (with [message] below when given):
/// true when confirmed, false when cancelled or dismissed.
///
/// [confirm] and [cancel] label the two buttons (the material *OK* and
/// *Cancel* labels by default); [destructive] paints the confirm button in
/// the error color (a deletion).
Future<bool> festenaoConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? confirm,
  String? cancel,
  bool destructive = false,
}) async {
  var labels = MaterialLocalizations.of(context);
  var result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancel ?? labels.cancelButtonLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm ?? labels.okButtonLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for a text in a dialog titled [title]: the text entered, null when
/// cancelled or dismissed.
///
/// [label] labels the field, [initial] fills it, [keyboardType] and
/// [obscure] (a password) set it up; [confirm] and [cancel] label the two
/// buttons (the material *OK* and *Cancel* labels by default). Submitting
/// the field confirms.
Future<String?> festenaoTextDialog(
  BuildContext context, {
  required String title,
  String? label,
  String? initial,
  String? confirm,
  String? cancel,
  TextInputType? keyboardType,
  bool obscure = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextDialog(
    title: title,
    label: label,
    initial: initial,
    confirm: confirm,
    cancel: cancel,
    keyboardType: keyboardType,
    obscure: obscure,
  ),
);

/// The dialog of [festenaoTextDialog]: it owns its controller, disposed with
/// it once the closing animation is over (not when the dialog returns: the
/// field is still drawn then).
class _TextDialog extends StatefulWidget {
  final String title;
  final String? label;
  final String? initial;
  final String? confirm;
  final String? cancel;
  final TextInputType? keyboardType;
  final bool obscure;

  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirm,
    required this.cancel,
    required this.keyboardType,
    required this.obscure,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var labels = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscure,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancel ?? labels.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirm ?? labels.okButtonLabel),
        ),
      ],
    );
  }
}

/// Runs [action], showing [success] in a snack bar when it succeeds and its
/// error otherwise, as [errorText] words it for the user (the error as is
/// by default): true when it succeeded.
///
/// Nothing is shown once [context] is no longer mounted.
Future<bool> festenaoRunWithSnack(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
  String Function(Object error)? errorText,
}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      festenaoShowSnack(context, success);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      festenaoShowSnack(context, errorText?.call(e) ?? '$e');
    }
    return false;
  }
}
