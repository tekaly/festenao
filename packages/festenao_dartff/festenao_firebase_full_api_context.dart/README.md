# festenao full api context

Every read and write goes through the api function: the rules
(`festenao_firebase` preset `full_api_context`, generated) refuse the client
everything. Reserved for the time reads go through the api too; for now
`test/emulator_full_test.dart` checks the client refusal and the api only
groups (email invites) on the emulator.
