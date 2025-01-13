import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_firebase_ui_firestore/firebase_ui_firestore.dart';

/// Entity list screen
class FsEntityListScreen extends StatefulWidget {
  /// Entity list screen
  const FsEntityListScreen({super.key});

  @override
  State<FsEntityListScreen> createState() => _FsEntityListScreenState();
}

class _FsEntityListScreenState extends State<FsEntityListScreen> {
  var firebaseContext = globalAdminAppFirebaseContext;

  var userId = '1';
  var collection = 'entities';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All entities')),
      body: FirestoreListView(
        query: globalEntityDatabase.projectDb.fsEntityCollectionRef
            .raw(globalEntityDatabase.firestore),
        itemBuilder: (BuildContext context, DocumentSnapshot doc) {
          return ListTile(title: Text(doc.ref.id));
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {
        globalEntityDatabase.projectDb
            .createEntity(userId: userId, entity: FsProject()..name.v = 'test');
      }),
    );
  }
}

/// Go to the entity list screen
Future<void> goToFsEntityListScreen(BuildContext context) async {
  await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const FsEntityListScreen()));
}
