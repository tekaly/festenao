/// The protobuf (`.pb`) viewer and editor, without any schema, to plug into
/// the file system explorer or to open on its own.
///
/// A [PbFileScreen] lists the fields of a protobuf file as a tree — number,
/// wire type, value — expands embedded messages and groups, prints the whole
/// file like `protoc --decode_raw`, and edits it when the explorer allows
/// it. It is built on `tekartik_app_pb`, linked only by the apps importing
/// this library.
///
/// ```dart
/// await goToFileSystemExplorerScreen(
///   context,
///   explorer: explorer,
///   fileOpeners: [pbFileSystemOpener],
/// );
/// ```
library;

export 'src/pb_explorer/pb_file_screen.dart'
    show
        PbFileScreen,
        goToPbFileScreen,
        pbFileExtensions,
        pbFileSystemOpener,
        pbNodeCopyText,
        pbNodeDetails;
export 'src/pb_explorer/pb_tree.dart'
    show
        PbBytesView,
        PbNode,
        PbTree,
        PbTreeRow,
        PbValueFormat,
        pbBytesViewOf,
        pbEditFormatsOf,
        pbFormatValue,
        pbParseValue,
        pbWireTypeLabel;
