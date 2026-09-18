/// The avatar name meaning no avatar.
const avatarNameNone = '--none--';

/// A player avatar, identified by its name.
class Avatar {
  /// The avatar name (a team code for instance).
  final String name;

  /// Creates an avatar.
  const Avatar(this.name);

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is Avatar) {
      return name == other.name;
    }
    return false;
  }

  @override
  String toString() => 'Avatar($name)';
}

/// The avatars a player can pick from.
class Avatars {
  late final List<Avatar> _list;

  /// Creates the avatars from a list of codes.
  Avatars.fromTeamCodes(List<String> teamCodes) {
    _list = teamCodes.map((e) => Avatar(e)).toList();
  }

  /// The avatars.
  List<Avatar> get avatars => _list;

  /// True if [value] is one of the avatars.
  bool contains(Avatar value) => _list.contains(value);
}
