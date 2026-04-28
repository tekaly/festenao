import 'package:fs_shim/fs.dart';

/// Global projects file system bloc.
late FestenaoUserProjectsFsBloc globalFestenaoUserProjectsFsBloc;

/// Festenao user projects file system bloc.
class FestenaoUserProjectsFsBloc {
  /// The underlying file system.
  final FileSystem fs;

  /// Festenao user projects file system bloc.
  FestenaoUserProjectsFsBloc({required this.fs});
}
