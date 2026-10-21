import 'dart:typed_data';

import 'package:tekartik_app_pb/pb.dart';

/// How a length delimited value is shown and edited, the wire not saying
/// whether it holds text, a message, bytes or packed numbers.
enum PbBytesView {
  /// Utf8 text.
  string('string'),

  /// An embedded message, its fields listed below it.
  message('message'),

  /// Raw bytes, in hex.
  bytes('bytes'),

  /// Packed varints (repeated ints, enums, bools).
  packedVarints('packed varint'),

  /// Packed fixed32 values (repeated fixed32, sfixed32, float).
  packedFixed32('packed i32'),

  /// Packed fixed64 values (repeated fixed64, sfixed64, double).
  packedFixed64('packed i64');

  /// What the badge and the "view as" menu say.
  final String label;

  const PbBytesView(this.label);
}

/// The [PbBytesView] matching what [pbGuessBytesKind] guesses.
PbBytesView pbBytesViewOf(PbBytesKind kind) => switch (kind) {
  PbBytesKind.string => PbBytesView.string,
  PbBytesKind.message => PbBytesView.message,
  PbBytesKind.bytes => PbBytesView.bytes,
};

/// The badge of a wire type.
String pbWireTypeLabel(PbWireType wireType) => switch (wireType) {
  PbWireType.varint => 'varint',
  PbWireType.fixed64 => 'i64',
  PbWireType.lengthDelimited => 'len',
  PbWireType.startGroup || PbWireType.endGroup => 'group',
  PbWireType.fixed32 => 'i32',
};

/// One field of a [PbTree]: its number, its value and, for an embedded
/// message or a group, its fields below it.
///
/// Every change re-encodes the messages above it, so [value] is always what
/// would be written, and an untouched field keeps its exact bytes.
class PbNode {
  /// The node holding this field, null for the root of the tree.
  final PbNode? parent;

  int _number;
  PbValue _value;
  PbBytesView? _view;
  List<PbNode>? _children;

  /// True when the fields below it are listed.
  var expanded = false;

  PbNode._(this.parent, this._number, this._value, PbBytesView? view)
    : _view = view;

  /// Node of [field], [view] guessed when it is length delimited.
  PbNode._field(PbNode parent, PbField field, {PbBytesView? view})
    : this._(
        parent,
        field.number,
        field.value,
        view ?? _guessView(field.value),
      );

  static PbBytesView? _guessView(PbValue value) => switch (value) {
    PbLengthDelimited value => pbBytesViewOf(value.guessKind()),
    _ => null,
  };

  /// The field number, 0 for the root.
  int get number => _number;

  /// The value, as it would be written.
  PbValue get value => _value;

  /// How a length delimited value is shown, null for any other.
  PbBytesView? get view => _view;

  /// True for the root of the tree, the file itself.
  bool get isRoot => parent == null;

  /// How deep it is, 0 for the fields of the file.
  int get depth {
    var depth = -1;
    for (var node = parent; node != null; node = node.parent) {
      depth++;
    }
    return depth;
  }

  /// True when it holds fields: an embedded message or a group.
  bool get isContainer => _value is PbGroup || _view == PbBytesView.message;

  /// The bytes of a length delimited value.
  Uint8List get _bytes => (_value as PbLengthDelimited).rawBytes!;

  /// The fields below it, decoded the first time they are asked for; empty
  /// when it is not a [isContainer].
  List<PbNode> get children {
    if (!isContainer) {
      return const [];
    }
    return _children ??= [
      for (var field in _message.fields) PbNode._field(this, field),
    ];
  }

  PbMessage get _message => switch (_value) {
    PbGroup(:var message) => message,
    _ => pbDecodeMessage(_bytes),
  };

  /// The message its fields make.
  PbMessage get message => PbMessage([
    for (var child in children) PbField(child.number, child.value),
  ]);

  /// True when it can be shown as [view]: the bytes decode that way.
  bool canView(PbBytesView view) {
    var value = _value;
    if (value is! PbLengthDelimited) {
      return false;
    }
    return switch (view) {
      PbBytesView.bytes => true,
      PbBytesView.string => value.tryDecodeString() != null,
      PbBytesView.message => value.tryDecodeMessage() != null,
      PbBytesView.packedVarints => value.tryDecodePackedVarints() != null,
      PbBytesView.packedFixed32 => value.tryDecodePackedFixed32() != null,
      PbBytesView.packedFixed64 => value.tryDecodePackedFixed64() != null,
    };
  }

  /// Shows a length delimited value as [view], false when its bytes do not
  /// decode that way (see [canView]).
  bool setView(PbBytesView view) {
    if (!canView(view)) {
      return false;
    }
    _view = view;
    _children = null;
    return true;
  }

  /// Replaces the value, shown as [view] when length delimited (guessed when
  /// null).
  void setValue(PbValue value, {PbBytesView? view}) {
    if (isRoot) {
      throw StateError('the root holds the file');
    }
    _value = value;
    _view = value is PbLengthDelimited ? view ?? _guessView(value) : null;
    _children = null;
    parent!._childrenChanged();
  }

  /// Renumbers the field.
  void setNumber(int number) {
    if (isRoot) {
      throw StateError('the root has no number');
    }
    pbCheckFieldNumber(number);
    _number = number;
    parent!._childrenChanged();
  }

  /// Adds field [number] holding [value] below it, at [index] (the end by
  /// default), shown as [view] when length delimited (guessed when null).
  PbNode add(int number, PbValue value, {int? index, PbBytesView? view}) {
    if (!isContainer) {
      throw StateError('field $number holds no message');
    }
    var node = PbNode._field(this, PbField(number, value), view: view);
    children.insert(index ?? children.length, node);
    expanded = true;
    _childrenChanged();
    return node;
  }

  /// Removes the field from its message.
  void remove() {
    var parent = this.parent;
    if (parent == null) {
      throw StateError('the root holds the file');
    }
    parent.children.remove(this);
    parent._childrenChanged();
  }

  /// Re-encodes the value from the fields below it, then the messages above.
  void _childrenChanged() {
    var message = this.message;
    _value = _value is PbGroup
        ? PbGroup(message)
        : PbBytes(pbEncodeMessage(message));
    parent?._childrenChanged();
  }

  /// A one line summary of the value, for the listing.
  String get preview {
    var value = _value;
    switch (value) {
      case PbVarint():
        var text = value.toUnsignedString();
        // A negative int32/int64 is how most of these come.
        return value.hi >= 0x80000000
            ? '$text (${value.toSignedBigInt()})'
            : text;
      case PbFixed32():
        return '0x${value.toHex()}  ${value.toUint32()}  '
            '${_shortDouble(value.toFloat())}f';
      case PbFixed64():
        return '0x${value.toHex()}  ${value.toUnsignedString()}  '
            '${_shortDouble(value.toDouble())}';
      case PbGroup(:var message):
        return _fieldCount(message.fields.length);
      case PbLengthDelimited():
        return _bytesPreview(value);
    }
  }

  String _bytesPreview(PbLengthDelimited value) {
    switch (_view!) {
      case PbBytesView.message:
        return _fieldCount(children.length);
      case PbBytesView.string:
        var text = value.tryDecodeString() ?? '';
        return '"${pbEscapeString(_ellipsize(text, 200))}"';
      case PbBytesView.bytes:
        var bytes = _bytes;
        return '${bytes.length} bytes  '
            '${_hex(bytes.take(24))}${bytes.length > 24 ? ' …' : ''}';
      case PbBytesView.packedVarints:
        return _list(
          value.tryDecodePackedVarints()!.map((v) => v.toUnsignedString()),
        );
      case PbBytesView.packedFixed32:
        return _list(
          value.tryDecodePackedFixed32()!.map((v) => '${v.toUint32()}'),
        );
      case PbBytesView.packedFixed64:
        return _list(
          value.tryDecodePackedFixed64()!.map((v) => v.toUnsignedString()),
        );
    }
  }

  @override
  String toString() => '$number: $preview';
}

String _fieldCount(int count) => count == 1 ? '1 field' : '$count fields';

String _ellipsize(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max)}…';

String _list(Iterable<String> values) {
  var list = values.toList();
  var shown = list.take(16).join(', ');
  return '[$shown${list.length > 16 ? ', … ${list.length} values' : ''}]';
}

String _shortDouble(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(1);
  }
  var text = value.toString();
  return text.length > 12 ? value.toStringAsExponential(4) : text;
}

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');

/// A row of the listing: a node and how deep it is.
typedef PbTreeRow = ({PbNode node, int depth});

/// A protobuf file as a tree of fields to browse and edit, without any
/// schema.
class PbTree {
  /// The file itself, its fields being the top ones.
  final PbNode root;

  PbTree._(this.root);

  /// The tree of [bytes], throwing a [PbFormatException] when they are not a
  /// protobuf message.
  factory PbTree.decode(List<int> bytes) {
    var copy = Uint8List.fromList(bytes);
    // Decodes now, so that invalid bytes throw here and not when listed.
    pbDecodeMessage(copy);
    return PbTree._(PbNode._(null, 0, PbBytes(copy), PbBytesView.message));
  }

  /// The top fields.
  List<PbNode> get fields => root.children;

  /// The file as it would be written.
  Uint8List get bytes => (root.value as PbBytes).bytes;

  /// The message of the file.
  PbMessage get message => root.message;

  /// The rows to list: every field whose parents are all expanded.
  List<PbTreeRow> get rows {
    var rows = <PbTreeRow>[];
    void visit(PbNode node, int depth) {
      for (var child in node.children) {
        rows.add((node: child, depth: depth));
        if (child.expanded && child.isContainer) {
          visit(child, depth + 1);
        }
      }
    }

    visit(root, 0);
    return rows;
  }

  /// Expands every message and group, down to [maxDepth] levels.
  void expandAll({int maxDepth = 32}) {
    void visit(PbNode node, int depth) {
      if (depth > maxDepth) {
        return;
      }
      for (var child in node.children) {
        if (child.isContainer) {
          child.expanded = true;
          visit(child, depth + 1);
        }
      }
    }

    visit(root, 0);
  }

  /// Collapses every message and group.
  void collapseAll() {
    void visit(PbNode node) {
      for (var child in node._children ?? const <PbNode>[]) {
        child.expanded = false;
        visit(child);
      }
    }

    visit(root);
  }
}

/// How a value is typed in, each fitting some wire types.
enum PbValueFormat {
  /// A decimal (or `0x` hex) integer in a varint: int32, int64, uint32,
  /// uint64, enum.
  integer('int', PbWireType.varint),

  /// A zigzag encoded integer (sint32, sint64).
  zigzag('sint', PbWireType.varint),

  /// true or false.
  boolean('bool', PbWireType.varint),

  /// A decimal (or `0x` hex) integer on 4 bytes: fixed32, sfixed32.
  fixed32('fixed32', PbWireType.fixed32),

  /// A single precision float.
  float32('float', PbWireType.fixed32),

  /// A decimal (or `0x` hex) integer on 8 bytes: fixed64, sfixed64.
  fixed64('fixed64', PbWireType.fixed64),

  /// A double.
  float64('double', PbWireType.fixed64),

  /// Utf8 text.
  string('string', PbWireType.lengthDelimited),

  /// Bytes in hex, spaces optional.
  bytes('bytes (hex)', PbWireType.lengthDelimited),

  /// Integers separated by commas or spaces, packed as varints.
  packedVarints('packed varints', PbWireType.lengthDelimited),

  /// Integers separated by commas or spaces, packed as fixed32.
  packedFixed32('packed fixed32', PbWireType.lengthDelimited),

  /// Integers separated by commas or spaces, packed as fixed64.
  packedFixed64('packed fixed64', PbWireType.lengthDelimited),

  /// An empty embedded message, its fields added after.
  message('message', PbWireType.lengthDelimited),

  /// An empty group, its fields added after.
  group('group', PbWireType.startGroup);

  /// What the format picker says.
  final String label;

  /// The wire type it writes.
  final PbWireType wireType;

  const PbValueFormat(this.label, this.wireType);

  /// True when it has no text to type: an empty message or group.
  bool get isEmptyContainer => this == message || this == group;

  /// The view a value typed this way is shown as, null when not length
  /// delimited.
  PbBytesView? get view => switch (this) {
    string => PbBytesView.string,
    bytes => PbBytesView.bytes,
    packedVarints => PbBytesView.packedVarints,
    packedFixed32 => PbBytesView.packedFixed32,
    packedFixed64 => PbBytesView.packedFixed64,
    message => PbBytesView.message,
    _ => null,
  };
}

/// The formats [value] can be edited as, the one it is shown as first.
List<PbValueFormat> pbEditFormatsOf(PbValue value, PbBytesView? view) =>
    switch (value) {
      PbVarint() => [
        PbValueFormat.integer,
        PbValueFormat.zigzag,
        PbValueFormat.boolean,
      ],
      PbFixed32() => [PbValueFormat.fixed32, PbValueFormat.float32],
      PbFixed64() => [PbValueFormat.fixed64, PbValueFormat.float64],
      PbGroup() => const [],
      PbLengthDelimited() => switch (view) {
        PbBytesView.string => [PbValueFormat.string, PbValueFormat.bytes],
        PbBytesView.packedVarints => [
          PbValueFormat.packedVarints,
          PbValueFormat.bytes,
        ],
        PbBytesView.packedFixed32 => [
          PbValueFormat.packedFixed32,
          PbValueFormat.bytes,
        ],
        PbBytesView.packedFixed64 => [
          PbValueFormat.packedFixed64,
          PbValueFormat.bytes,
        ],
        _ => [PbValueFormat.bytes, PbValueFormat.string],
      },
    };

final _minInt64 = -(BigInt.one << 63);
final _maxInt64 = (BigInt.one << 63) - BigInt.one;
final _maxUint64 = (BigInt.one << 64) - BigInt.one;

/// [value] as text in [format], what an editor starts from.
String pbFormatValue(PbValue value, PbValueFormat format) {
  switch (format) {
    case PbValueFormat.integer:
      if (value is PbVarint) {
        // A negative int32/int64 is how most of these come.
        return value.hi >= 0x80000000
            ? value.toSignedBigInt().toString()
            : value.toUnsignedString();
      }
      return '';
    case PbValueFormat.fixed32:
      return value is PbFixed32 ? '${value.toUint32()}' : '';
    case PbValueFormat.fixed64:
      return value is PbFixed64 ? value.toUnsignedString() : '';
    case PbValueFormat.zigzag:
      if (value is PbVarint) {
        var bits = value.toUnsignedBigInt();
        var half = bits >> 1;
        return (bits.isEven ? half : -half - BigInt.one).toString();
      }
      return '';
    case PbValueFormat.boolean:
      return value is PbVarint ? '${value.toBool()}' : '';
    case PbValueFormat.float32:
      return value is PbFixed32 ? '${value.toFloat()}' : '';
    case PbValueFormat.float64:
      return value is PbFixed64 ? '${value.toDouble()}' : '';
    case PbValueFormat.string:
      return value is PbLengthDelimited ? value.tryDecodeString() ?? '' : '';
    case PbValueFormat.bytes:
      return value is PbLengthDelimited ? _hex(value.rawBytes ?? const []) : '';
    case PbValueFormat.packedVarints:
      return value is PbLengthDelimited
          ? (value.tryDecodePackedVarints() ?? const [])
                .map((v) => v.toUnsignedString())
                .join(', ')
          : '';
    case PbValueFormat.packedFixed32:
      return value is PbLengthDelimited
          ? (value.tryDecodePackedFixed32() ?? const [])
                .map((v) => '${v.toUint32()}')
                .join(', ')
          : '';
    case PbValueFormat.packedFixed64:
      return value is PbLengthDelimited
          ? (value.tryDecodePackedFixed64() ?? const [])
                .map((v) => v.toUnsignedString())
                .join(', ')
          : '';
    case PbValueFormat.message:
    case PbValueFormat.group:
      return '';
  }
}

BigInt _parseInteger(String text, BigInt min, BigInt max) {
  var trimmed = text.trim();
  var negative = trimmed.startsWith('-');
  var digits = negative ? trimmed.substring(1) : trimmed;
  BigInt? value;
  if (digits.toLowerCase().startsWith('0x')) {
    value = BigInt.tryParse(digits.substring(2), radix: 16);
  } else {
    value = BigInt.tryParse(digits);
  }
  if (value == null || digits.startsWith('-') || digits.startsWith('+')) {
    throw FormatException('not an integer: $trimmed');
  }
  if (negative) {
    value = -value;
  }
  if (value < min || value > max) {
    throw FormatException('out of range [$min, $max]: $trimmed');
  }
  return value;
}

double _parseDouble(String text) {
  var value = double.tryParse(text.trim());
  if (value == null) {
    throw FormatException('not a number: ${text.trim()}');
  }
  return value;
}

List<String> _items(String text) =>
    text.split(RegExp(r'[\s,]+')).where((item) => item.isNotEmpty).toList();

List<int> _parseHex(String text) {
  var cleaned = text.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.length.isOdd) {
    throw const FormatException('an odd number of hex digits');
  }
  return [
    for (var i = 0; i < cleaned.length; i += 2)
      int.tryParse(cleaned.substring(i, i + 2), radix: 16) ??
          (throw FormatException(
            'not a hex byte: ${cleaned.substring(i, i + 2)}',
          )),
  ];
}

/// The value [text] gives in [format], throwing a [FormatException] saying
/// what is wrong with it.
PbValue pbParseValue(String text, PbValueFormat format) {
  switch (format) {
    case PbValueFormat.integer:
      return PbVarint.fromBigInt(_parseInteger(text, _minInt64, _maxUint64));
    case PbValueFormat.fixed32:
      return PbFixed32.fromInt(
        _parseInteger(
          text,
          BigInt.from(-0x80000000),
          BigInt.from(0xffffffff),
        ).toInt(),
      );
    case PbValueFormat.fixed64:
      return PbFixed64.fromBigInt(_parseInteger(text, _minInt64, _maxUint64));
    case PbValueFormat.zigzag:
      var value = _parseInteger(text, _minInt64, _maxInt64);
      return PbVarint.fromBigInt(
        value.isNegative
            ? -value * BigInt.two - BigInt.one
            : value * BigInt.two,
      );
    case PbValueFormat.boolean:
      return switch (text.trim().toLowerCase()) {
        'true' || '1' => PbVarint.fromBool(true),
        'false' || '0' => PbVarint.fromBool(false),
        _ => throw FormatException('not a bool: ${text.trim()}'),
      };
    case PbValueFormat.float32:
      return PbFixed32.fromFloat(_parseDouble(text));
    case PbValueFormat.float64:
      return PbFixed64.fromDouble(_parseDouble(text));
    case PbValueFormat.string:
      return PbBytes.string(text);
    case PbValueFormat.bytes:
      return PbBytes.fromList(_parseHex(text));
    case PbValueFormat.packedVarints:
      var writer = PbWriter();
      for (var item in _items(text)) {
        writer.writeVarint(
          PbVarint.fromBigInt(_parseInteger(item, _minInt64, _maxUint64)),
        );
      }
      return PbBytes(writer.toBytes());
    case PbValueFormat.packedFixed32:
      var writer = PbWriter();
      for (var item in _items(text)) {
        var value = _parseInteger(
          item,
          BigInt.from(-0x80000000),
          BigInt.from(0xffffffff),
        );
        writer.writeFixed32(PbFixed32.fromInt(value.toInt()));
      }
      return PbBytes(writer.toBytes());
    case PbValueFormat.packedFixed64:
      var writer = PbWriter();
      for (var item in _items(text)) {
        writer.writeFixed64(
          PbFixed64.fromBigInt(_parseInteger(item, _minInt64, _maxUint64)),
        );
      }
      return PbBytes(writer.toBytes());
    case PbValueFormat.message:
      return PbBytes(Uint8List(0));
    case PbValueFormat.group:
      return PbGroup(PbMessage());
  }
}
