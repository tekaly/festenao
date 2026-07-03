import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:path/path.dart';

Future<void> main(List<String> args) async {
  var shell = Shell(workingDirectory: 'functions');
  await shell.run(
    'dart compile exe bin/server.dart --target-os=linux --target-arch=x64',
  );
  // `dart compile exe` always appends `.exe`, but the functions runtime
  // expects the binary at `bin/server` (no extension).
  await File(
    join('functions', 'bin', 'server.exe'),
  ).copy(join('functions', 'bin', 'server'));
}
