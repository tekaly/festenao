import 'package:festenao_common/data/object_editor.dart';
import 'package:flutter/services.dart';

/// The [ObjectClipboard] the flutter editors use, mirrored to the clipboard of
/// the system.
///
/// Copying also puts the json text on the system clipboard, so a value crosses
/// apps; pasting prefers what the system clipboard holds when it is json the
/// editor can read, so a value copied anywhere else comes in.
class FlutterObjectClipboard {
  /// The clipboard the values themselves go through.
  final ObjectClipboard clipboard;

  /// Clipboard mirroring [clipboard], the global one by default.
  FlutterObjectClipboard({ObjectClipboard? clipboard})
    : clipboard = clipboard ?? globalObjectClipboard;

  /// Copies [data] and puts its json text on the system clipboard.
  Future<ObjectClipboardData> setData(ObjectClipboardData data) async {
    clipboard.setData(data);
    await Clipboard.setData(ClipboardData(text: data.text));
    return data;
  }

  /// Copies [value], encoded through [typeRegistry].
  Future<ObjectClipboardData> copy(
    Object? value, {
    required ObjectTypeRegistry typeRegistry,
    required String label,
  }) => setData(
    ObjectClipboardData(
      jsonValue: typeRegistry.toJsonEncodable(value),
      label: label,
    ),
  );

  /// What should be pasted: the json the system clipboard holds when it reads
  /// as one, what was last copied here otherwise.
  ///
  /// Null when neither has anything to paste.
  Future<ObjectClipboardData?> read() async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      // No clipboard on this platform, what was copied here still pastes.
    }
    var held = clipboard.data;
    if (text != null) {
      // The very text this clipboard put there: keep the richer data, it
      // carries where the value came from.
      if (held != null && held.text == text) {
        return held;
      }
      var parsed = ObjectClipboardData.tryParse(text, label: 'clipboard');
      if (parsed != null) {
        return parsed;
      }
    }
    return held;
  }

  /// True when something may be pasted, without reading the system clipboard.
  ///
  /// A menu uses it to decide whether to offer a paste; the paste itself goes
  /// through [read], which may find more.
  bool get isNotEmpty => clipboard.isNotEmpty;

  /// Fires each time something is copied here.
  Stream<ObjectClipboardData?> get onChanged => clipboard.onChanged;
}

/// The clipboard the flutter editors use unless they are given another one.
final globalFlutterObjectClipboard = FlutterObjectClipboard();
