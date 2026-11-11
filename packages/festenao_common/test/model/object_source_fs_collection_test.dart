import 'package:festenao_common/src/data/model/object_source_fs.dart';
import 'package:festenao_common/src/data/model/object_text_format.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:test/test.dart';

void main() {
  test('a listed file is read back through its id', () async {
    var fs = newFileSystemMemory();
    await fs.directory('/dir').create(recursive: true);
    await fs.file('/dir/config.yml').writeAsString('name: one\n');
    await fs.file('/dir/Other.JSON').writeAsString('{"name": "two"}');
    var yaml = FsObjectCollection(
      fs.directory('/dir'),
      format: objectYamlFormat,
    );
    expect(await yaml.listIds(), ['config']);
    expect(await yaml.source('config').read(), {'name': 'one'});
    var json = FsObjectCollection(fs.directory('/dir'));
    expect(await json.listIds(), ['Other']);
    expect(await json.source('Other').read(), {'name': 'two'});
    // An id never listed takes the first extension.
    expect(json.source('new').title, '/dir/new.json');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('limit applies after the sort', () async {
    var fs = newFileSystemMemory();
    await fs.directory('/dir').create(recursive: true);
    for (var id in ['c', 'a', 'd', 'b']) {
      await fs.file('/dir/$id.json').writeAsString('{}');
    }
    var json = FsObjectCollection(fs.directory('/dir'));
    expect(await json.listIds(limit: 2), ['a', 'b']);
    expect(await json.listIds(), ['a', 'b', 'c', 'd']);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
