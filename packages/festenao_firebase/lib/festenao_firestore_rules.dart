/// The tkcms/festenao firestore rule sets and the festenao presets.
///
/// [TkCmsFirestoreRules] builds the generic entity access rules at any
/// nesting depth (entity, access, invites, public flag, per user private data,
/// creator and standalone invite flows); the `festenao*Rules()` presets
/// assemble them into the rule files of the festenao firebase contexts.
library;

export 'firestore_rules.dart';
export 'src/festenao/festenao_rules_presets.dart';
export 'src/festenao/tkcms_rules.dart';
