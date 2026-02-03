import 'package:dev_build/shell.dart';

Future<void> main() async {
  await run('flutter gen-l10n');
  if (whichSync('tkarb_format') != null) {
    await run('tkarb_format');
  }
}
