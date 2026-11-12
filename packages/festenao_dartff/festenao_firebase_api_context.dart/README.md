# festenao api context

The api function owns every change of the access documents (entity creation,
invites, joins); the client reads its entities, writes their data and its
private area directly: the rules (`festenao_firebase` preset `api_context`,
generated). `test/project_api_emulator_test.dart` runs the client access
groups against these rules and the `festenao_dartff` functions
(`../functions`) on the emulator.
