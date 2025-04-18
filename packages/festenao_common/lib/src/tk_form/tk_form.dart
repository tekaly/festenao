/// Form Player Form
abstract class TkFormPlayerForm {
  /// Form id
  String get id;

  /// Form title
  String get name;
}

/// Debug helper
extension TkFormPlayerFormExt on TkFormPlayerForm {
  /// Debug string
  String toDebugString() {
    return 'PlayerForm(id: $id, name: $name)';
  }
}

/// Base form player form
class TkFormPlayerFormBase implements TkFormPlayerForm {
  @override
  final String id;
  @override
  final String name;

  /// Constructor
  TkFormPlayerFormBase({required this.id, required this.name});
}
