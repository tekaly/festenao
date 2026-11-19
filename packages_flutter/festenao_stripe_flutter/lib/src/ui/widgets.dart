import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../client.dart';
import '../format.dart';

/// The color of a live client.
const stripeManagerLiveColor = Color(0xFFC62828);

/// The color of a test client.
const stripeManagerTestColor = Color(0xFFEF6C00);

/// A `TEST` / `LIVE` chip of [client].
class StripeManagerModeChip extends StatelessWidget {
  /// The client.
  final StripeManagerClient client;

  /// A chip of [client].
  const StripeManagerModeChip({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: client.isLive ? stripeManagerLiveColor : stripeManagerTestColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        client.isRestricted ? '${client.modeLabel} RK' : client.modeLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A red banner on every screen of a live client: real money.
class StripeManagerLiveBanner extends StatelessWidget {
  /// The client.
  final StripeManagerClient client;

  /// A banner of [client] (nothing for a test one).
  const StripeManagerLiveBanner({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    if (!client.isLive) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: stripeManagerLiveColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'LIVE: ${client.name}, real payments and real money',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

/// A scaffold with the live banner of [client] above [body].
class StripeManagerScaffold extends StatelessWidget {
  /// The client.
  final StripeManagerClient client;

  /// The title.
  final String title;

  /// The body.
  final Widget body;

  /// The actions of the app bar.
  final List<Widget>? actions;

  /// The floating action button.
  final Widget? floatingActionButton;

  /// A scaffold of [client].
  const StripeManagerScaffold({
    super.key,
    required this.client,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            StripeManagerModeChip(client: client),
          ],
        ),
        actions: actions,
      ),
      body: Column(
        children: [
          StripeManagerLiveBanner(client: client),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Asks to confirm a write; for a live [client] the user types `LIVE`.
Future<bool> stripeManagerConfirm(
  BuildContext context, {
  required StripeManagerClient client,
  required String title,
  required String message,
  String action = 'OK',
}) async {
  var result = await showDialog<bool>(
    context: context,
    builder: (context) => _ConfirmDialog(
      client: client,
      title: title,
      message: message,
      action: action,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  final StripeManagerClient client;
  final String title;
  final String message;
  final String action;

  const _ConfirmDialog({
    required this.client,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var client = widget.client;
    var typed = _controller.text.trim().toUpperCase() == 'LIVE';
    var canConfirm = !client.isLive || typed;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (client.isLive) ...[
            const SizedBox(height: 16),
            Text(
              'LIVE account (${client.name}): type LIVE to confirm',
              style: const TextStyle(color: stripeManagerLiveColor),
            ),
            TextField(
              key: const ValueKey('stripe_manager_live_confirm'),
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canConfirm ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// Runs [action], shows [success] or the Stripe error in a snack bar;
/// returns true on success.
Future<bool> stripeManagerRun(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  var messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(stripeApiErrorMessage(e)),
        backgroundColor: stripeManagerLiveColor,
      ),
    );
    return false;
  }
}

/// Copies [text] to the clipboard and says it.
Future<void> stripeManagerCopy(
  BuildContext context,
  String text, {
  String? what,
}) async {
  var messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(SnackBar(content: Text('${what ?? text} copied')));
}

/// Shows the result of [load] with [builder]; a progress, or the error with
/// a retry. [reloadKey]: a new value reloads.
class StripeManagerFutureView<T> extends StatefulWidget {
  /// The loader.
  final Future<T> Function() load;

  /// The view of the result.
  final Widget Function(BuildContext context, T value, VoidCallback reload)
  builder;

  /// A new value reloads.
  final Object? reloadKey;

  /// A view of [load].
  const StripeManagerFutureView({
    super.key,
    required this.load,
    required this.builder,
    this.reloadKey,
  });

  @override
  State<StripeManagerFutureView<T>> createState() =>
      _StripeManagerFutureViewState<T>();
}

class _StripeManagerFutureViewState<T>
    extends State<StripeManagerFutureView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant StripeManagerFutureView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) {
      _future = widget.load();
    }
  }

  void _reload() {
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stripeApiErrorMessage(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

/// A label and a value, tap to copy the value when [copy].
class StripeManagerInfoTile extends StatelessWidget {
  /// The label.
  final String label;

  /// The value, `-` when null.
  final String? value;

  /// Tap copies the value.
  final bool copy;

  /// A tile of [label].
  const StripeManagerInfoTile({
    super.key,
    required this.label,
    required this.value,
    this.copy = false,
  });

  @override
  Widget build(BuildContext context) {
    var value = this.value;
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: SelectableText(value ?? '-'),
      trailing: copy && value != null ? const Icon(Icons.copy, size: 16) : null,
      onTap: copy && value != null
          ? () => stripeManagerCopy(context, value, what: label)
          : null,
    );
  }
}

/// A section title.
class StripeManagerSectionTitle extends StatelessWidget {
  /// The title.
  final String title;

  /// A section [title].
  const StripeManagerSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// A period drop down.
class StripeManagerPeriodSelector extends StatelessWidget {
  /// The period.
  final StripeManagerPeriod period;

  /// Called with the new one.
  final ValueChanged<StripeManagerPeriod> onChanged;

  /// A selector of [period].
  const StripeManagerPeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<StripeManagerPeriod>(
      value: period,
      items: [
        for (var value in StripeManagerPeriod.values)
          DropdownMenuItem(value: value, child: Text(value.label)),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

/// Asks for a text (a name, an amount); null when cancelled.
Future<String?> stripeManagerAskText(
  BuildContext context, {
  required String title,
  String? label,
  String? initialValue,
  TextInputType? keyboardType,
  String? Function(String text)? validator,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextDialog(
    title: title,
    label: label,
    initialValue: initialValue,
    keyboardType: keyboardType,
    validator: validator,
  ),
);

class _TextDialog extends StatefulWidget {
  final String title;
  final String? label;
  final String? initialValue;
  final TextInputType? keyboardType;
  final String? Function(String text)? validator;

  const _TextDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.keyboardType,
    required this.validator,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var error = widget.validator?.call(_controller.text);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('stripe_manager_text'),
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(labelText: widget.label, errorText: error),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: error == null
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// An amount typed in euros (`10`, `10.5`, `10,50`) as cents, null when not
/// an amount above 0.
int? stripeManagerParseCents(String text) {
  var normalized = text.trim().replaceAll(',', '.').replaceAll('€', '').trim();
  var value = num.tryParse(normalized);
  if (value == null || !value.isFinite || value <= 0) {
    return null;
  }
  return (value * 100).round();
}

/// The error of an amount [text], null when valid.
String? stripeManagerAmountError(String text) =>
    stripeManagerParseCents(text) == null ? 'An amount above 0' : null;
