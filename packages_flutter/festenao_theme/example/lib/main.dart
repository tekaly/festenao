import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/gallery_app.dart';
import 'package:material_ui/material_ui.dart';

/// The festenao themes gallery.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Poppins and JetBrains Mono, under the bare names the themes ask for.
  await loadFestenaoFonts();
  runApp(const GalleryApp());
}
