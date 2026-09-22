/// Editing a json-like object — a file, a database record, a document — with
/// a generic editor.
///
/// An [ObjectEditor] holds the tree being edited, an [ObjectTypeRegistry] says
/// what a value may be (the basic json types, plus a timestamp, a blob, or any
/// custom type a backend adds), and an [ObjectSource] says where the object is
/// read from and written back to.
///
/// Sources are provided for a json or yaml file ([FsObjectSource], through
/// `fs_shim`, so it works on the web too), a sembast record, an sdb record, a
/// firestore document and a `cv` model.
///
/// The console editor and the io file helpers are in `object_editor_io.dart`,
/// which this library deliberately does not export: everything here imports on
/// the web.
library;

export '../src/data/model/object_clipboard.dart'
    show
        ObjectClipboard,
        ObjectClipboardData,
        ObjectCollectionClipboardExt,
        ObjectEditorClipboardExt,
        ObjectSourceClipboardExt,
        globalObjectClipboard;
export '../src/data/model/object_cv.dart'
    show
        CvObjectField,
        CvObjectSchema,
        CvObjectSource,
        ObjectEditorCvExt,
        cvObjectSchema,
        cvObjectTypeIdOf;
export '../src/data/model/object_edit_operation.dart'
    show
        ObjectEditOperation,
        ObjectInsertOperation,
        ObjectRemoveOperation,
        ObjectSetOperation;
export '../src/data/model/object_editor.dart'
    show ObjectEditor, ObjectEditorTypeExt, objectDeepClone;
export '../src/data/model/object_node.dart' show ObjectNode;
export '../src/data/model/object_path.dart' show ObjectPath;
export '../src/data/model/object_source.dart'
    show
        MemoryObjectSource,
        ObjectCollection,
        ObjectRepository,
        ObjectSource,
        ObjectSourceEditor,
        ReadOnlyException;
export '../src/data/model/object_source_firestore.dart'
    show
        FirestoreBlobTypeHandler,
        FirestoreDocumentReferenceTypeHandler,
        FirestoreGeoPointTypeHandler,
        FirestoreObjectCollection,
        FirestoreObjectRepository,
        FirestoreObjectSource,
        FirestoreTimestampTypeHandler,
        firestoreNewReferencePath,
        firestoreObjectTypeRegistry;
export '../src/data/model/object_source_fs.dart'
    show FsObjectCollection, FsObjectSource;
export '../src/data/model/object_source_sdb.dart'
    show
        SdbObjectCollection,
        SdbObjectRepository,
        SdbObjectSource,
        sdbObjectTypeRegistry;
export '../src/data/model/object_source_sembast.dart'
    show
        SembastBlobTypeHandler,
        SembastObjectCollection,
        SembastObjectRepository,
        SembastObjectSource,
        SembastTimestampTypeHandler,
        sembastObjectTypeHandlers,
        sembastObjectTypeRegistry;
export '../src/data/model/object_text_format.dart'
    show
        ObjectJsonFormat,
        ObjectTextFormat,
        ObjectYamlFormat,
        objectJsonFormat,
        objectTextFormatOf,
        objectTextFormats,
        objectYamlFormat;
export '../src/data/model/object_type.dart'
    show
        ObjectCustomTypeHandler,
        ObjectValueTypeHandler,
        objectBasicTypeHandlers,
        objectCustomTypePrefix,
        objectTypeBool,
        objectTypeBytes,
        objectTypeDateTime,
        objectTypeDouble,
        objectTypeInt,
        objectTypeList,
        objectTypeMap,
        objectTypeNull,
        objectTypeString,
        objectTypeTruncate,
        objectTypeUnknown;
export '../src/data/model/object_type_registry.dart'
    show ObjectTypeRegistry, defaultObjectTypeRegistry;
