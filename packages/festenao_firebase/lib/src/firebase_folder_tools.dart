import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

/// Writes [text] (a generated rules or cors file) to the file [path] when
/// its content differs, unless [check]: then it only tells. Returns true
/// when the file changed (or would change).
///
/// Prints the outcome: `up to date`, `would change` or `written`.
Future<bool> festenaoWriteGeneratedFile(
  String path,
  String text, {
  bool check = false,
}) async {
  var file = File(path);
  var existing = file.existsSync() ? await file.readAsString() : null;
  if (existing == text) {
    stdout.writeln('${file.path}: up to date');
    return false;
  }
  if (check) {
    stdout.writeln('${file.path}: would change');
  } else {
    await file.writeAsString(text);
    stdout.writeln('${file.path}: written');
  }
  return true;
}

/// Applies the cors file [corsFileName] (in the firebase folder [path], the
/// current directory by default) to the storage [bucket] of [projectId]
/// with the gcloud cli (`gcloud auth login` first), then prints the
/// configuration the bucket has. Without it a browser cannot read what it
/// downloads from storage.
Future<void> festenaoApplyStorageCors({
  required String bucket,
  required String projectId,
  required String corsFileName,
  String? path,
}) async {
  var shell = Shell(workingDirectory: path ?? '.');
  await shell.run(
    'gcloud storage buckets update gs://$bucket '
    '--project $projectId '
    '--cors-file=${shellArgument(corsFileName)}',
  );
  await shell.run(
    'gcloud storage buckets describe gs://$bucket '
    '--project $projectId --format=json(cors_config)',
  );
}

/// Runs the rest tests of [flavorContext] (`test/rest_<flavor>_test.dart`
/// of the firebase package [path], the current directory by default, in
/// its `rest` preset) against the deployed functions, rules and hosting;
/// throws when they fail.
Future<void> festenaoRunRestTests(
  FlavorContext flavorContext, {
  String? path,
}) async {
  var file = join('test', 'rest_${flavorContext.flavor}_test.dart');
  await Shell(
    workingDirectory: path ?? '.',
  ).run('dart test -P rest ${shellArgument(file)}');
}
