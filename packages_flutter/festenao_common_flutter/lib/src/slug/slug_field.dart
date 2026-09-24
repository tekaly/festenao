import 'dart:async';

import 'package:festenao_common/festenao_slug.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Where a slug being edited stands.
enum FestenaoSlugStatus {
  /// Nothing typed.
  empty,

  /// Not a valid slug (see [FestenaoSlugOptions.check]).
  invalid,

  /// Valid, its availability is being checked.
  checking,

  /// Valid and free.
  available,

  /// The slug the entity already has.
  current,

  /// Taken by another entity.
  taken,

  /// The availability could not be checked (offline...).
  error;

  /// True when the slug may be saved: free, already ours, or valid when
  /// nothing checks the availability.
  bool get isAcceptable =>
      this == FestenaoSlugStatus.available ||
      this == FestenaoSlugStatus.current;
}

/// The texts of a [FestenaoSlugField], english by default.
class FestenaoSlugFieldTexts {
  /// The field label.
  final String label;

  /// Shown while checking.
  final String checking;

  /// Shown when free.
  final String available;

  /// Shown when it is the current slug.
  final String current;

  /// Shown when taken.
  final String taken;

  /// Shown when the check failed.
  final String error;

  /// The message of an invalid slug.
  final String Function(FestenaoSlugError error, FestenaoSlugOptions options)
  invalid;

  /// The texts of a [FestenaoSlugField].
  const FestenaoSlugFieldTexts({
    this.label = 'Url',
    this.checking = 'Checking...',
    this.available = 'Available',
    this.current = 'Current url',
    this.taken = 'Already taken',
    this.error = 'Could not check, try again',
    this.invalid = festenaoSlugErrorTextEn,
  });
}

/// The english message of a slug [error].
String festenaoSlugErrorTextEn(
  FestenaoSlugError error,
  FestenaoSlugOptions options,
) => switch (error) {
  FestenaoSlugError.tooShort => 'At least ${options.minLength} characters',
  FestenaoSlugError.tooLong => 'At most ${options.maxLength} characters',
  FestenaoSlugError.invalidCharacters =>
    'Lower case letters, digits and dashes only',
  FestenaoSlugError.reserved => 'This word is reserved',
};

/// Formats the input of a slug as it is typed: lower case, accents
/// stripped, spaces and anything else turned into single dashes (a trailing
/// one is kept while typing), capped to [options] max length.
class FestenaoSlugInputFormatter extends TextInputFormatter {
  /// The slug rules.
  final FestenaoSlugOptions options;

  /// Formats the input of a slug.
  const FestenaoSlugInputFormatter({this.options = festenaoSlugOptionsDefault});

  /// The formatted [text].
  String format(String text) {
    var trailingDash = RegExp(r'[^a-zA-Z0-9À-ÿ]$').hasMatch(text);
    var slug = festenaoSlugify(text, maxLength: options.maxLength);
    if (trailingDash && slug.isNotEmpty && slug.length < options.maxLength) {
      slug = '$slug-';
    }
    return slug;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = format(newValue.text);
    if (text == newValue.text) {
      return newValue;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A text field editing a slug: formatted as typed, validated, and checked
/// for availability (debounced) when [isAvailable] is given.
///
/// The value is the text of [controller] (a trailing dash, kept while
/// typing, makes it invalid until something follows). [onStatusChanged]
/// tells the form whether it may save ([FestenaoSlugStatus.isAcceptable]).
class FestenaoSlugField extends StatefulWidget {
  /// The edited slug.
  final TextEditingController controller;

  /// The slug rules.
  final FestenaoSlugOptions options;

  /// The slug the entity already has: not checked, shown as current.
  final String? currentSlug;

  /// Whether a slug is free (typically [FestenaoSlugRegistry.isAvailable]),
  /// null to only validate.
  final Future<bool> Function(String slug)? isAvailable;

  /// Shown before the slug (`my-app.web.app/e/`).
  final String? prefixText;

  /// The texts.
  final FestenaoSlugFieldTexts texts;

  /// Called whenever the status changes.
  final ValueChanged<FestenaoSlugStatus>? onStatusChanged;

  /// Delay after the last key stroke before checking the availability.
  final Duration debounce;

  /// Whether the field is enabled.
  final bool enabled;

  /// The field decoration border, the theme one when null.
  final InputBorder? border;

  /// A text field editing a slug.
  const FestenaoSlugField({
    super.key,
    required this.controller,
    this.options = festenaoSlugOptionsDefault,
    this.currentSlug,
    this.isAvailable,
    this.prefixText,
    this.texts = const FestenaoSlugFieldTexts(),
    this.onStatusChanged,
    this.debounce = const Duration(milliseconds: 400),
    this.enabled = true,
    this.border,
  });

  @override
  State<FestenaoSlugField> createState() => _FestenaoSlugFieldState();
}

class _FestenaoSlugFieldState extends State<FestenaoSlugField> {
  var _status = FestenaoSlugStatus.empty;
  var _building = false;
  FestenaoSlugError? _error;
  Timer? _timer;
  String? _checkedText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _building = true;
    _onChanged();
    _building = false;
    // The first status, even an unchanged one (empty).
    _notify(_status);
  }

  @override
  void didUpdateWidget(covariant FestenaoSlugField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (oldWidget.currentSlug != widget.currentSlug) {
      _checkedText = null;
      _building = true;
      _onChanged();
      _building = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _setStatus(FestenaoSlugStatus status, {FestenaoSlugError? error}) {
    if (status == _status && error == _error) {
      return;
    }
    _status = status;
    _error = error;
    // While building (init, a new current slug) the build that follows shows
    // it already.
    if (!_building && mounted) {
      setState(() {});
    }
    _notify(status);
  }

  /// Tell [FestenaoSlugField.onStatusChanged], after the frame when called
  /// while building: the parent typically calls setState.
  void _notify(FestenaoSlugStatus status) {
    var callback = widget.onStatusChanged;
    if (callback == null) {
      return;
    }
    if (_building ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _status == status) {
          callback(status);
        }
      });
    } else {
      callback(status);
    }
  }

  void _onChanged() {
    var text = widget.controller.text;
    if (text == _checkedText) {
      return;
    }
    _checkedText = text;
    _timer?.cancel();
    if (text.isEmpty) {
      _setStatus(FestenaoSlugStatus.empty);
      return;
    }
    var error = widget.options.check(text);
    if (error != null) {
      _setStatus(FestenaoSlugStatus.invalid, error: error);
      return;
    }
    if (text == widget.currentSlug) {
      _setStatus(FestenaoSlugStatus.current);
      return;
    }
    var isAvailable = widget.isAvailable;
    if (isAvailable == null) {
      _setStatus(FestenaoSlugStatus.available);
      return;
    }
    _setStatus(FestenaoSlugStatus.checking);
    _timer = Timer(widget.debounce, () async {
      FestenaoSlugStatus status;
      try {
        status = await isAvailable(text)
            ? FestenaoSlugStatus.available
            : FestenaoSlugStatus.taken;
      } catch (_) {
        status = FestenaoSlugStatus.error;
      }
      // A result for a text that changed meanwhile is stale.
      if (mounted && widget.controller.text == text) {
        _setStatus(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var texts = widget.texts;
    var colorScheme = Theme.of(context).colorScheme;
    String? helperText;
    String? errorText;
    Widget? suffixIcon;
    switch (_status) {
      case FestenaoSlugStatus.empty:
        break;
      case FestenaoSlugStatus.invalid:
        errorText = texts.invalid(_error!, widget.options);
      case FestenaoSlugStatus.checking:
        helperText = texts.checking;
        suffixIcon = const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case FestenaoSlugStatus.available:
        helperText = texts.available;
        suffixIcon = Icon(Icons.check_circle, color: colorScheme.primary);
      case FestenaoSlugStatus.current:
        helperText = texts.current;
        suffixIcon = Icon(Icons.link, color: colorScheme.primary);
      case FestenaoSlugStatus.taken:
        errorText = texts.taken;
        suffixIcon = Icon(Icons.error_outline, color: colorScheme.error);
      case FestenaoSlugStatus.error:
        errorText = texts.error;
        suffixIcon = Icon(Icons.cloud_off, color: colorScheme.error);
    }
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.url,
      inputFormatters: [FestenaoSlugInputFormatter(options: widget.options)],
      decoration: InputDecoration(
        labelText: texts.label,
        prefixText: widget.prefixText,
        helperText: helperText,
        errorText: errorText,
        suffixIcon: suffixIcon,
        border: widget.border,
      ),
    );
  }
}
