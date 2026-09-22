import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:tekaly_file_download/download_file.dart';
import 'package:tekaly_file_picker_flutter/file_picker_flutter.dart';

/// Downloads the file [entry] of [explorer] to the device: the browser
/// downloads it on the web, a save dialog is shown elsewhere.
Future<void> downloadFileSystemFile(
  FileSystemExplorer explorer,
  FileSystemEntry entry,
) async {
  var bytes = await explorer.readAsBytes(entry.path);
  await downloadFile(DownloadFileInfo(filename: entry.name, data: bytes));
}

/// Zips the whole tree under [path] of [explorer] and downloads it as
/// [zipName].
///
/// The archive keeps [path] itself as the top folder of the zip, the way a
/// download of a repository or a shared folder usually does.
Future<void> downloadFileSystemDirectoryAsZip(
  FileSystemExplorer explorer,
  String path, {
  required String zipName,
}) async {
  var archive = Archive();
  Future<void> walk(String directory) async {
    for (var entry in await explorer.list(directory)) {
      if (entry.isDirectory) {
        await walk(entry.path);
      } else {
        var bytes = await explorer.readAsBytes(entry.path);
        archive.addFile(ArchiveFile.bytes(entry.path, bytes));
      }
    }
  }

  await walk(path);
  var zipBytes = ZipEncoder().encodeBytes(archive);
  await downloadFile(
    DownloadFileInfo(filename: zipName, data: Uint8List.fromList(zipBytes)),
  );
}

/// Lets the user pick one or more files from the device and writes them
/// under [path] of [explorer], each keeping its own name.
///
/// The paths written, empty when the user cancelled the pick.
Future<List<String>> uploadFilesToFileSystem(
  FileSystemExplorer explorer,
  String path,
) async {
  var picked = await tekalyFilePickerFlutter.pickFiles();
  var written = <String>[];
  for (var file in picked) {
    var bytes = await file.readAsBytes();
    var entryPath = path.isEmpty ? file.name : '$path/${file.name}';
    await explorer.writeAsBytes(entryPath, bytes);
    written.add(entryPath);
  }
  return written;
}

/// Copies [entry] of [explorer] to [destinationPath] of the same explorer,
/// under its own name. Answers the path it was copied to.
Future<String> copyFileSystemEntryTo(
  FileSystemExplorer explorer,
  FileSystemEntry entry,
  String destinationPath,
) async {
  var bytes = await explorer.readAsBytes(entry.path);
  var newPath = destinationPath.isEmpty
      ? entry.name
      : '$destinationPath/${entry.name}';
  await explorer.writeAsBytes(newPath, bytes);
  return newPath;
}
