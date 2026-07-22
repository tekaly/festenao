// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_system_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app [FileSystem].
///
/// Defaults to [fileSystemDefault] (io or web depending on platform).
/// Override to sandbox the file system to an app-specific location or to
/// provide an in-memory file system in tests.

@ProviderFor(festenaoFileSystem)
final festenaoFileSystemProvider = FestenaoFileSystemProvider._();

/// The app [FileSystem].
///
/// Defaults to [fileSystemDefault] (io or web depending on platform).
/// Override to sandbox the file system to an app-specific location or to
/// provide an in-memory file system in tests.

final class FestenaoFileSystemProvider
    extends $FunctionalProvider<FileSystem, FileSystem, FileSystem>
    with $Provider<FileSystem> {
  /// The app [FileSystem].
  ///
  /// Defaults to [fileSystemDefault] (io or web depending on platform).
  /// Override to sandbox the file system to an app-specific location or to
  /// provide an in-memory file system in tests.
  FestenaoFileSystemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'festenaoFileSystemProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$festenaoFileSystemHash();

  @$internal
  @override
  $ProviderElement<FileSystem> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileSystem create(Ref ref) {
    return festenaoFileSystem(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileSystem value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileSystem>(value),
    );
  }
}

String _$festenaoFileSystemHash() =>
    r'c8ea93935e2b45ba8b02870d5bda245b10fda339';
