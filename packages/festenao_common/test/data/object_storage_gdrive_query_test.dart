import 'dart:convert';

import 'package:festenao_common/data/object_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tekartik_gdrive_api_utils/gdrive.dart';
import 'package:test/test.dart';

void main() {
  test('drive query values are escaped', () async {
    var queries = <String>[];
    var client = MockClient((request) async {
      var q = request.url.queryParameters['q'];
      if (q != null) {
        queries.add(q);
      }
      var body = request.method == 'GET'
          ? {'files': <Object?>[]}
          : {'id': 'new', 'name': 'x', 'mimeType': 'text/plain'};
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    var storage = ObjectStorageGdrive(gdrive: GDrive(client: client));
    await storage.upload(
      'folderId',
      name: "l'été.mp3",
      data: Uint8List.fromList([1, 2, 3]),
      mimeType: 'audio/mpeg',
    );
    // A folder id trying to widen the query.
    await storage.list(r"x' in parents or name != 'zz' or 'y\");
    expect(queries, [
      r"'folderId' in parents and name='l\'été.mp3' and trashed = false",
      r"'x\' in parents or name != \'zz\' or \'y\\' in parents and trashed = false",
    ]);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
