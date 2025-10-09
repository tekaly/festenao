/// Form Player Form abstraction used by form players.
abstract class TkFormPlayerForm {
  /// The form identifier.
  String get id;

  /// The form title or name.
  String get name;
}

/// Debug helper extensions for [TkFormPlayerForm].
extension TkFormPlayerFormExt on TkFormPlayerForm {
  /// Returns a debug string representation of the form.
  String toDebugString() {
    return 'PlayerForm(id: $id, name: $name)';
  }
}

/// Basic implementation of [TkFormPlayerForm].
class TkFormPlayerFormBase implements TkFormPlayerForm {
  @override
  final String id;
  @override
  final String name;

  /// Creates a new [TkFormPlayerFormBase] with [id] and [name].
  TkFormPlayerFormBase({required this.id, required this.name});
}
