/// Stores the service account of the admin builds and tools where they look
/// for it (`festenao_common/firebase/festenao_service_account_io.dart`): a file
/// of `~/.config/tekartik/festenao/service_accounts`, the
/// `FESTENAO_SERVICE_ACCOUNT` variable of the ds env user file, or both.
///
/// ```sh
/// # The file, and the variable pointing to it.
/// dart run festenao_support:festenao_service_account write ~/Downloads/sa.json --ds-env
/// dart run festenao_support:festenao_service_account list
/// ```
///
/// It never prints a private key, nor the other ds env variables.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:festenao_common/firebase/festenao_service_account_io.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';

const _usage =
    '''
Stores the service account of the festenao admin builds and tools.

Usage: festenao_service_account <command> [arguments]

  list                       The service accounts found: \$$festenaoServiceAccountEnvKey
                             (environment, then ds env) and the files.
  write <file.json | ->      Stores a service account (- reads stdin).
      --[no-]file            In <dir>/<project_id>.json (default on).
      --ds-env               Sets \$$festenaoServiceAccountEnvKey in the ds env user
                             file: to the file path, to the json itself with
                             --no-file.
  delete <project_id>        Removes the file, and the ds env variable when it is
                             this project's.
  unset                      Removes \$$festenaoServiceAccountEnvKey from the ds env
                             user file.
  dir                        Prints the directory of the files.

The directory is <dir>: ${'~/.config/tekartik/festenao/service_accounts'} on linux.
''';

Future<void> main(List<String> arguments) async {
  var parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('list')
    ..addCommand(
      'write',
      ArgParser()
        ..addFlag('file', defaultsTo: true)
        ..addFlag('ds-env', negatable: false),
    )
    ..addCommand('delete')
    ..addCommand('unset')
    ..addCommand('dir');
  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.write(_usage);
    exitCode = 64;
    return;
  }
  var command = results.command;
  if (results.flag('help')) {
    stdout.write(_usage);
    return;
  }
  if (command == null) {
    if (results.rest.isNotEmpty) {
      stderr.writeln('Unknown command ${results.rest.first}');
      exitCode = 64;
    }
    stderr.write(_usage);
    return;
  }
  try {
    switch (command.name) {
      case 'list':
        await _list();
      case 'write':
        await _write(command);
      case 'delete':
        await _delete(command);
      case 'unset':
        await festenaoSetServiceAccountDsEnv(null);
        stdout.writeln('$festenaoServiceAccountEnvKey removed from ds env');
      case 'dir':
        stdout.writeln(festenaoServiceAccountDirPath());
    }
  } on Object catch (e) {
    stderr.writeln(e is StateError ? e.message : '$e');
    exitCode = 1;
  }
}

String _describe(FestenaoServiceAccount account) =>
    '${account.projectId}  ${account.clientEmail}'
    '${account.privateKeyId == null ? '' : '  key ${account.privateKeyId}'}'
    '\n    ${account.source}';

Future<void> _list() async {
  var found = await festenaoFindServiceAccounts();
  if (found.fromEnv == null) {
    stdout.writeln('$festenaoServiceAccountEnvKey is not set');
  }
  if (found.accounts.isEmpty) {
    stdout.writeln('No service account in ${festenaoServiceAccountDirPath()}');
  }
  for (var account in found.accounts) {
    stdout.writeln(_describe(account));
  }
  for (var error in found.errors) {
    stderr.writeln('error: $error');
  }
}

Future<void> _write(ArgResults command) async {
  if (command.rest.length != 1) {
    throw StateError('write takes one service account file (or -)');
  }
  var source = command.rest.first;
  var text = source == '-'
      ? await utf8.decoder.bind(stdin).join()
      : await File(festenaoExpandHomePath(source)).readAsString();
  var map = festenaoServiceAccountMapFromText(text);
  var error = festenaoServiceAccountMapError(map);
  if (error != null) {
    throw StateError('$source: $error');
  }
  var toFile = command.flag('file');
  var toDsEnv = command.flag('ds-env');
  if (!toFile && !toDsEnv) {
    throw StateError('Nothing to write, use --file or --ds-env');
  }
  String? path;
  if (toFile) {
    path = await festenaoWriteServiceAccountFile(map!);
    stdout.writeln('${map['project_id']} written to $path');
  }
  if (toDsEnv) {
    await festenaoSetServiceAccountDsEnv(path ?? jsonEncode(map));
    stdout.writeln(
      '$festenaoServiceAccountEnvKey set in ds env'
      '${path == null ? ' (the json)' : ' to $path'}',
    );
  }
}

/// True when the ds env variable is the service account of [projectId].
Future<bool> _isDsEnvOf(String projectId) async {
  var value = userEnvironment[festenaoServiceAccountEnvKey];
  if (value == null) {
    return false;
  }
  try {
    var account = await festenaoServiceAccountFromEnv(
      environment: {festenaoServiceAccountEnvKey: value},
    );
    return account?.projectId == projectId;
  } on StateError {
    // A file gone already: its name tells.
    return basename(value.trim()) == '$projectId.json';
  }
}

Future<void> _delete(ArgResults command) async {
  if (command.rest.length != 1) {
    throw StateError('delete takes one project id');
  }
  var projectId = command.rest.first;
  var isDsEnv = await _isDsEnvOf(projectId);
  if (await festenaoDeleteServiceAccountFile(projectId)) {
    stdout.writeln(
      '$projectId removed from ${festenaoServiceAccountDirPath()}',
    );
  } else {
    stdout.writeln('No file for $projectId');
  }
  if (isDsEnv) {
    await festenaoSetServiceAccountDsEnv(null);
    stdout.writeln('$festenaoServiceAccountEnvKey removed from ds env');
  }
}
