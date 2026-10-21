import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:material_ui/material_ui.dart';

/// A viewer an app plugs into the file system explorer for files it does not
/// know otherwise: a tap on a file with one of [extensions] opens it there,
/// and "open as…" offers it for any file.
///
/// Keeping it a plug-in keeps the format out of every app that does not ask
/// for it: `pb_explorer_flutter.dart` gives `pbFileSystemOpener`, the
/// protobuf viewer, only linked by the apps listing it.
///
/// ```dart
/// await goToFileSystemExplorerScreen(
///   context,
///   explorer: explorer,
///   fileOpeners: [pbFileSystemOpener],
/// );
/// ```
class FileSystemFileOpener {
  /// What "open as…" offers, `Protobuf` for instance.
  final String label;

  /// The icon of the files it opens, in the listing and in "open as…".
  final IconData icon;

  /// The badge of the files it opens in the listing, instead of their kind.
  final String kindLabel;

  /// The extensions a tap opens with it, lower case with their dot (`.pb`).
  final Set<String> extensions;

  /// Opens the file [path] of [explorer], completing when its screen is
  /// closed (the listing reloads then).
  final Future<void> Function(
    BuildContext context,
    FileSystemExplorer explorer,
    String path,
  )
  open;

  /// Opener of [extensions] files.
  const FileSystemFileOpener({
    required this.label,
    required this.icon,
    required this.kindLabel,
    required this.extensions,
    required this.open,
  });

  /// True when a tap on [entry] opens it with this opener.
  bool matches(FileSystemEntry entry) {
    if (entry.isDirectory) {
      return false;
    }
    var name = entry.name;
    var dot = name.lastIndexOf('.');
    return dot >= 0 && extensions.contains(name.substring(dot).toLowerCase());
  }
}

/// The first of [openers] that opens [entry] on a tap, null when none does.
FileSystemFileOpener? fileSystemFileOpenerOf(
  Iterable<FileSystemFileOpener> openers,
  FileSystemEntry entry,
) {
  for (var opener in openers) {
    if (opener.matches(entry)) {
      return opener;
    }
  }
  return null;
}

/// An action an app adds to the app bar of the file system explorer, on the
/// directory listed: switching to a view of its own of that directory, or to
/// another way of exploring it.
///
/// The explorer knows nothing of what it does; it passes it on to the
/// directories it opens, so it stays there all the way down.
///
/// ```dart
/// FileSystemExplorerScreen(
///   explorer: explorer,
///   directoryActions: [
///     FileSystemDirectoryAction(
///       label: 'Images',
///       icon: Icons.photo_library_outlined,
///       onPressed: (context, explorer, path) => showImagesOf(context, path),
///     ),
///   ],
/// );
/// ```
class FileSystemDirectoryAction {
  /// What its tooltip says.
  final String label;

  /// Its icon in the app bar.
  final IconData icon;

  /// Runs it on the directory [path] of [explorer].
  final void Function(
    BuildContext context,
    FileSystemExplorer explorer,
    String path,
  )
  onPressed;

  /// Action [label].
  const FileSystemDirectoryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}
