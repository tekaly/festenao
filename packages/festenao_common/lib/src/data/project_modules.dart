/// Whether [module] is on in a project whose modules are [modules]: every
/// module is on when [modules] is null (a project created before the
/// modules, or by an app without any).
bool festenaoProjectHasModule(List<String>? modules, String module) =>
    modules == null || modules.contains(module);

/// Whether two module lists are the same, in the same order.
bool festenaoProjectModulesEquals(List<String>? a, List<String>? b) {
  if (a == null || b == null) {
    return a == b;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
