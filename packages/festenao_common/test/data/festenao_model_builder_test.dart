import 'package:festenao_common/data/festenao_db.dart';
import 'package:test/test.dart';

class DbParent extends DbStringRecordBase {
  final child = cvModelField<Child>('child');

  @override
  List<CvField> get fields => [child];
}

class Child extends CvModelBase {
  final value = CvField<String>('value');

  @override
  List<CvField> get fields => [value];
}

class ParentWithList extends CvModelBase {
  final children = cvModelListField<Child>('children');

  @override
  List<CvField> get fields => [children];
}

void initModelBuilders() {
  cvAddBuilder<DbParent>((_) => DbParent());
  cvAddBuilder<Child>((_) => Child());
  cvAddBuilder<ParentWithList>((_) => ParentWithList());
}

void main() {
  initModelBuilders();
  group('festenao_model_builder', () {
    test('cvModelField', () async {
      var parent = DbParent()..child.v = (Child()..value.v = 'test');
      expect(parent.toMap(), {
        'child': {'value': 'test'},
      });
      expect(parent.toMap().cv<DbParent>(), parent);
    });
    test('cvModelListField', () async {
      var parent = ParentWithList()..children.v = [Child()..value.v = 'test'];
      expect(parent.toMap(), {
        'children': [
          {'value': 'test'},
        ],
      });
      expect(parent.toMap().cv<ParentWithList>(), parent);
    });
  });
}
