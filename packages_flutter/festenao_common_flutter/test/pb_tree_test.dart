import 'package:festenao_common_flutter/pb_explorer_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_pb/pb.dart';

/// A test result like an android `test-result.pb`: a status (2) and test
/// results (3), each a test case (1: class, 3: method) and a status (2).
List<int> sampleBytes() => pbEncodeMessage(
  PbMessage()
    ..addInt(2, 3)
    ..addMessage(
      3,
      PbMessage()
        ..addMessage(
          1,
          PbMessage()
            ..addString(1, 'LocaleUtilsTest')
            ..addString(3, 'localeForLanguageTag'),
        )
        ..addInt(2, 3),
    )
    ..addString(4, 'done')
    ..addBytes(5, [0xff, 0x00, 0x01])
    ..addFixed32(6, 42)
    ..addFixed64(7, -1)
    ..addSint(8, -2),
);

void main() {
  group('PbTree', () {
    test('decodes the top fields, guessing their views', () {
      var tree = PbTree.decode(sampleBytes());
      var fields = tree.fields;
      expect(fields.map((node) => node.number), [2, 3, 4, 5, 6, 7, 8]);
      expect(fields[0].preview, '3');
      expect(fields[1].view, PbBytesView.message);
      expect(fields[1].isContainer, isTrue);
      expect(fields[1].preview, '2 fields');
      expect(fields[2].view, PbBytesView.string);
      expect(fields[2].preview, '"done"');
      expect(fields[3].view, PbBytesView.bytes);
      expect(fields[3].preview, '3 bytes  ff 00 01');
      expect(fields[4].preview, '0x0000002a  42  5.8855e-44f');
      expect(fields[5].preview, startsWith('0xffffffffffffffff  '));
      // A sint shows as its raw varint, the details show it zigzag decoded.
      expect(fields[6].preview, '3');
      expect(fields.every((node) => node.depth == 0), isTrue);
    });

    test('invalid bytes throw', () {
      expect(() => PbTree.decode([0x0f]), throwsFormatException);
    });

    test('rows follow the expanded nodes', () {
      var tree = PbTree.decode(sampleBytes());
      expect(tree.rows, hasLength(7));
      var result = tree.fields[1]..expanded = true;
      expect(tree.rows, hasLength(9));
      result.children.first.expanded = true;
      var rows = tree.rows;
      expect(rows, hasLength(11));
      expect(rows[2].depth, 1);
      expect(rows[3].depth, 2);
      expect(rows[3].node.preview, '"LocaleUtilsTest"');
      tree.collapseAll();
      expect(tree.rows, hasLength(7));
      tree.expandAll();
      expect(tree.rows, hasLength(11));
    });

    test('an untouched tree keeps its bytes', () {
      var bytes = sampleBytes();
      var tree = PbTree.decode(bytes)..expandAll();
      expect(tree.bytes, bytes);
    });

    test('editing a nested value re-encodes the messages above it', () {
      var tree = PbTree.decode(sampleBytes());
      var testCase = tree.fields[1].children.first;
      var method = testCase.children.last;
      method.setValue(PbBytes.string('renamed'));
      expect(method.preview, '"renamed"');

      var message = pbDecodeMessage(tree.bytes);
      expect(
        message.messageValue(3)!.messageValue(1)!.stringValue(3),
        'renamed',
      );
      // The other fields are untouched.
      expect(message.stringValue(4), 'done');
      expect(message.intValue(2), 3);
    });

    test('add, renumber, remove', () {
      var tree = PbTree.decode(sampleBytes());
      var result = tree.fields[1];
      result.add(9, PbVarint.fromInt(7));
      expect(result.expanded, isTrue);
      tree.root.add(10, PbBytes.string('top'));
      tree.fields[2].setNumber(11);
      tree.fields[3].remove();

      var message = pbDecodeMessage(tree.bytes);
      expect(message.numbers, [2, 3, 11, 6, 7, 8, 10]);
      expect(message.messageValue(3)!.intValue(9), 7);
      expect(message.stringValue(11), 'done');
      expect(message.stringValue(10), 'top');
      expect(() => tree.fields[0].add(1, PbVarint(0, 0)), throwsStateError);
      expect(() => tree.root.remove(), throwsStateError);
      expect(() => tree.fields[0].setNumber(0), throwsArgumentError);
    });

    test('groups', () {
      var tree = PbTree.decode(
        pbEncodeMessage(
          PbMessage()..addGroup(1, PbMessage()..addString(2, 'in group')),
        ),
      );
      var group = tree.fields.single;
      expect(group.isContainer, isTrue);
      expect(group.view, isNull);
      expect(group.preview, '1 field');
      group.children.single.setValue(PbBytes.string('changed'));
      expect(
        pbDecodeMessage(tree.bytes).messageValue(1)!.stringValue(2),
        'changed',
      );
    });

    test('view as', () {
      var tree = PbTree.decode(
        pbEncodeMessage(
          PbMessage()
            ..addBytes(1, [0x03, 0x8e, 0x02, 0x9e, 0xa7, 0x05])
            ..addString(2, 'hi'),
        ),
      );
      var packed = tree.fields[0];
      expect(packed.view, PbBytesView.bytes);
      expect(packed.canView(PbBytesView.packedVarints), isTrue);
      expect(packed.canView(PbBytesView.string), isFalse);
      expect(packed.setView(PbBytesView.string), isFalse);
      expect(packed.setView(PbBytesView.packedVarints), isTrue);
      expect(packed.preview, '[3, 270, 86942]');

      // 'hi' also decodes as a message (field 13, varint 105).
      var text = tree.fields[1];
      expect(text.view, PbBytesView.string);
      expect(text.setView(PbBytesView.message), isTrue);
      expect(text.isContainer, isTrue);
      expect(text.children.single.number, 13);
      expect(tree.fields[0].canView(PbBytesView.bytes), isTrue);
      // Viewing changes nothing written.
      expect(pbDecodeMessage(tree.bytes).stringValue(2), 'hi');
    });
  });

  group('values', () {
    test('formats each value for editing', () {
      expect(pbFormatValue(PbVarint.fromInt(-1), PbValueFormat.integer), '-1');
      expect(
        pbFormatValue(PbVarint.fromInt(150), PbValueFormat.integer),
        '150',
      );
      expect(pbFormatValue(PbVarint.fromSint(-2), PbValueFormat.zigzag), '-2');
      expect(
        pbFormatValue(PbVarint.fromBool(true), PbValueFormat.boolean),
        'true',
      );
      expect(
        pbFormatValue(PbFixed32.fromFloat(1.5), PbValueFormat.float32),
        '1.5',
      );
      expect(
        pbFormatValue(PbFixed32.fromInt(-1), PbValueFormat.fixed32),
        '4294967295',
      );
      expect(
        pbFormatValue(PbFixed64.fromDouble(2.5), PbValueFormat.float64),
        '2.5',
      );
      expect(
        pbFormatValue(PbFixed64.fromInt(-1), PbValueFormat.fixed64),
        '18446744073709551615',
      );
      expect(pbFormatValue(PbBytes.string('hé'), PbValueFormat.string), 'hé');
      expect(
        pbFormatValue(PbBytes.fromList([1, 0xab]), PbValueFormat.bytes),
        '01 ab',
      );
      expect(
        pbFormatValue(
          PbBytes.fromList([0x03, 0x8e, 0x02]),
          PbValueFormat.packedVarints,
        ),
        '3, 270',
      );
    });

    test('parses what is typed', () {
      expect(pbParseValue('150', PbValueFormat.integer), PbVarint.fromInt(150));
      expect(pbParseValue(' -1 ', PbValueFormat.integer), PbVarint.fromInt(-1));
      expect(pbParseValue('0x10', PbValueFormat.integer), PbVarint.fromInt(16));
      expect(
        pbParseValue('18446744073709551615', PbValueFormat.integer),
        PbVarint(0xffffffff, 0xffffffff),
      );
      expect(pbParseValue('-2', PbValueFormat.zigzag), PbVarint.fromSint(-2));
      expect(
        pbParseValue('true', PbValueFormat.boolean),
        PbVarint.fromBool(true),
      );
      expect(
        pbParseValue('0', PbValueFormat.boolean),
        PbVarint.fromBool(false),
      );
      expect(pbParseValue('-1', PbValueFormat.fixed32), PbFixed32(0xffffffff));
      expect(
        pbParseValue('1.5', PbValueFormat.float32),
        PbFixed32.fromFloat(1.5),
      );
      expect(pbParseValue('-1', PbValueFormat.fixed64), PbFixed64.fromInt(-1));
      expect(
        pbParseValue('2.5', PbValueFormat.float64),
        PbFixed64.fromDouble(2.5),
      );
      expect(pbParseValue('abc', PbValueFormat.string), PbBytes.string('abc'));
      expect(
        pbParseValue('01 AB', PbValueFormat.bytes),
        PbBytes.fromList([1, 0xab]),
      );
      expect(
        pbParseValue('3, 270 86942', PbValueFormat.packedVarints),
        PbBytes.fromList([0x03, 0x8e, 0x02, 0x9e, 0xa7, 0x05]),
      );
      expect(
        pbParseValue('1,2', PbValueFormat.packedFixed32),
        PbBytes.fromList([1, 0, 0, 0, 2, 0, 0, 0]),
      );
      expect(
        pbParseValue('1', PbValueFormat.packedFixed64),
        PbBytes.fromList([1, 0, 0, 0, 0, 0, 0, 0]),
      );
      expect(pbParseValue('', PbValueFormat.message), PbBytes.fromList([]));
      expect(pbParseValue('', PbValueFormat.group), PbGroup(PbMessage()));
    });

    test('refuses what does not parse', () {
      for (var (text, format) in [
        ('abc', PbValueFormat.integer),
        ('1.5', PbValueFormat.integer),
        ('--1', PbValueFormat.integer),
        ('18446744073709551616', PbValueFormat.integer),
        ('-9223372036854775809', PbValueFormat.integer),
        ('9223372036854775808', PbValueFormat.zigzag),
        ('yes', PbValueFormat.boolean),
        ('4294967296', PbValueFormat.fixed32),
        ('x', PbValueFormat.float32),
        ('0x1', PbValueFormat.bytes),
        ('zz', PbValueFormat.bytes),
        ('1, x', PbValueFormat.packedVarints),
      ]) {
        expect(
          () => pbParseValue(text, format),
          throwsFormatException,
          reason: '$text as ${format.name}',
        );
      }
    });

    test('edit formats follow the value', () {
      expect(pbEditFormatsOf(PbVarint(0, 0), null), [
        PbValueFormat.integer,
        PbValueFormat.zigzag,
        PbValueFormat.boolean,
      ]);
      expect(pbEditFormatsOf(PbFixed32(0), null).first, PbValueFormat.fixed32);
      expect(
        pbEditFormatsOf(PbFixed64(0, 0), null).last,
        PbValueFormat.float64,
      );
      expect(pbEditFormatsOf(PbGroup(PbMessage()), null), isEmpty);
      expect(
        pbEditFormatsOf(PbBytes.string('a'), PbBytesView.string).first,
        PbValueFormat.string,
      );
      expect(
        pbEditFormatsOf(PbBytes.fromList([1]), PbBytesView.bytes).first,
        PbValueFormat.bytes,
      );
      for (var format in PbValueFormat.values) {
        expect(
          format.view == null,
          !(format.wireType == PbWireType.lengthDelimited),
          reason: format.name,
        );
      }
    });
  });
}
