import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:test/test.dart';

const _timeout = Timeout(Duration(seconds: 30));

/// A file system holding a small tree, the explorer being rooted at `root`.
Future<FileSystem> _newFileSystem() async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.file('root/config.json').create(recursive: true);
  await fileSystem.file('root/config.json').writeAsString('{"name":"test"}');
  await fileSystem.file('root/other.json').create(recursive: true);
  await fileSystem.file('root/other.json').writeAsString('{"keep":"me"}');
  await fileSystem.file('root/sub/nested.json').create(recursive: true);
  await fileSystem.file('root/sub/nested.json').writeAsString('{}');
  return fileSystem;
}

void main() {
  group('delete', () {
    for (var path in ['.', './', 'sub/..', 'sub/../.']) {
      test('refuses the root as "$path"', () async {
        var fileSystem = await _newFileSystem();
        var explorer = FileSystemExplorer(
          fileSystem: fileSystem,
          rootPath: 'root',
        );
        await expectLater(
          explorer.delete(path),
          throwsA(isA<FileSystemExplorerPathException>()),
        );
        expect(await fileSystem.file('root/config.json').exists(), isTrue);
      }, timeout: _timeout);
    }
  });

  group('rename', () {
    test('refuses to replace an existing entry', () async {
      var fileSystem = await _newFileSystem();
      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      await expectLater(
        explorer.rename('config.json', 'other.json'),
        throwsA(isA<StateError>()),
      );
      expect(
        await fileSystem.file('root/other.json').readAsString(),
        '{"keep":"me"}',
      );
      expect(
        await fileSystem.file('root/config.json').readAsString(),
        '{"name":"test"}',
      );
      // Nor a directory.
      await expectLater(
        explorer.rename('config.json', 'sub'),
        throwsA(isA<StateError>()),
      );
    }, timeout: _timeout);

    for (var name in ['.', '..', 'a/b', r'a\b', r'..\x']) {
      test('refuses the name "$name"', () async {
        var fileSystem = await _newFileSystem();
        var explorer = FileSystemExplorer(
          fileSystem: fileSystem,
          rootPath: 'root',
        );
        await expectLater(
          explorer.rename('sub/nested.json', name),
          throwsA(isA<FileSystemExplorerPathException>()),
        );
        expect(await fileSystem.file('root/sub/nested.json').exists(), isTrue);
      }, timeout: _timeout);
    }
  });
}
