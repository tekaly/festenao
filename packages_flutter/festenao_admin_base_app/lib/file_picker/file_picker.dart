/// App file picker, on top of `tekaly_file_picker_flutter`.
///
/// The linux (`file_selector`/gtk) fallback and the last directory are handled
/// there, `file_picker` is never used directly.
library;

import 'package:tekaly_file_picker_flutter/file_picker_flutter.dart';

export 'package:tekaly_file_picker_flutter/file_picker_flutter.dart'
    show
        TekalyFilePicker,
        TekalyFilePickerExtension,
        TekalyPickFileType,
        TekalyPickedFile,
        TekalyPickedFileExtension;

/// The picker used by the app.
///
/// The global one when it has been initialized
/// (`initTekalyFilePickerFlutter()`, or a `TekalyFilePickerMemory` in tests),
/// the default flutter implementation otherwise.
TekalyFilePicker get appFilePicker =>
    tekalyFilePickerOrNull ?? tekalyFilePickerFlutter;

/// Pick an image file, `null` when the user cancelled.
Future<TekalyPickedFile?> pickImageFile() => appFilePicker.pickImageFile();

/// Pick any file, `null` when the user cancelled.
Future<TekalyPickedFile?> pickAnyFile() => appFilePicker.pickAnyFile();
