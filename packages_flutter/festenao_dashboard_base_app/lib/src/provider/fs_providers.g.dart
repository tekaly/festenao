// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fs_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App filesystem provider

@ProviderFor(fs)
final fsProvider = FsProvider._();

/// App filesystem provider

final class FsProvider
    extends
        $FunctionalProvider<
          AsyncValue<FileSystem>,
          FileSystem,
          FutureOr<FileSystem>
        >
    with $FutureModifier<FileSystem>, $FutureProvider<FileSystem> {
  /// App filesystem provider
  FsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fsHash();

  @$internal
  @override
  $FutureProviderElement<FileSystem> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FileSystem> create(Ref ref) {
    return fs(ref);
  }
}

String _$fsHash() => r'9838f91c81173816fd3fd22965b10256fe494477';
