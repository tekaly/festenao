import 'package:festenao_admin_base_app/screen/screen_import.dart';

/// Push a screen
Future<T?> festenaoPushScreen<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
}) async {
  var result = await Navigator.of(
    context,
  ).push<Object?>(MaterialPageRoute(builder: builder));
  if (result is T) {
    return result;
  }
  return null;
}
