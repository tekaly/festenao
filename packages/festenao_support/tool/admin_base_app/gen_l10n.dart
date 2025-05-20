import 'package:dev_build/shell.dart';
import 'package:fs_shim/utils/path.dart';
import 'package:tkcms_common/tkcms_common.dart';

var adminBaseAppPath = toNativePath(
  '../../packages_flutter/festenao_admin_base_app',
);
var adminBaseAppShell = Shell(workingDirectory: adminBaseAppPath);
Future<void> main() async {
  await adminBaseAppShell.run('flutter gen-l10n');
}
