import 'package:festenao_support/festenao_functions_menu.dart';
import 'package:tekartik_firebase_build/firebase_project_menu.dart';
import 'package:test/test.dart';

/// A project recording its deploys in [steps].
class _Project implements FirebaseProjectBuilder {
  _Project(this.name, this.steps);

  final String name;
  final List<String> steps;

  @override
  Future<void> deployFunctions({
    List<String>? functions,
    FirebaseProjectActionController? controller,
    bool? force,
  }) async {
    steps.add('deploy $name');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('deployDevTestThenProd', () {
    test('dev, its tests, then prod and its tests', () async {
      var steps = <String>[];
      var functions = FestenaoFunctionsBuild(
        dev: _Project('dev', steps),
        prod: _Project('prod', steps),
        restTests: (flavorContext) async {
          steps.add('test ${flavorContext.flavor}');
        },
      );
      await functions.deployDevTestThenProd();
      expect(steps, ['deploy dev', 'test dev', 'deploy prod', 'test prod']);
    });

    test('a failed dev test stops before prod', () async {
      var steps = <String>[];
      var functions = FestenaoFunctionsBuild(
        dev: _Project('dev', steps),
        prod: _Project('prod', steps),
        restTests: (flavorContext) async {
          steps.add('test ${flavorContext.flavor}');
          throw StateError('failed');
        },
      );
      await expectLater(
        functions.deployDevTestThenProd(),
        throwsA(isA<StateError>()),
      );
      expect(steps, ['deploy dev', 'test dev']);
    });
  });
}
