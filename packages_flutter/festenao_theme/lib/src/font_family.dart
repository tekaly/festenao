/// A font family shipped as assets of a package: the `family` name its files
/// are registered under, the `package` holding them and the `files`, relative
/// to the package `lib/` (asset key `packages/<package>/<file>`).
///
/// A record, so that a package describing its fonts needs no dependency: any
/// record of this shape is one.
typedef FestenaoFontFamily = ({
  String family,
  String package,
  List<String> files,
});
