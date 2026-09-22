import 'dart:typed_data';

import 'package:tekartik_firebase_firestore/firestore.dart';

/// Fills [firestore] with something to navigate: a few collections, documents
/// holding every firestore type, and a sub collection under one of them.
///
/// It is what a demo or a test opens the firestore explorer on, so every
/// editor has a value of its kind to show.
Future<void> fillDemoFirestore(Firestore firestore) async {
  await firestore.doc('settings/main').set({
    'name': 'Demo',
    'count': 42,
    'ratio': 0.5,
    'enabled': true,
    'nothing': null,
    'updatedAt': Timestamp.parse('2024-01-02T03:04:05.000Z'),
    'icon': Blob(Uint8List.fromList([1, 2, 3, 4])),
    'place': const GeoPoint(48.8584, 2.2945),
    'owner': firestore.doc('user/alice'),
    'tags': ['one', 'two'],
    'nested': {
      'deeper': {'value': 1},
    },
  });
  await firestore.doc('settings/theme').set({
    'name': 'Dark',
    'seed': 4283215696,
  });

  await firestore.doc('user/alice').set({
    'name': 'Alice',
    'joinedAt': Timestamp.parse('2023-06-01T08:00:00.000Z'),
  });
  await firestore.doc('user/bob').set({
    'name': 'Bob',
    'joinedAt': Timestamp.parse('2024-02-15T09:30:00.000Z'),
  });

  // A sub collection, so the explorer has a tree to walk and a backup has
  // something below the top level.
  await firestore.doc('user/alice/note/first').set({
    'title': 'First note',
    'body': 'What a sub collection looks like.',
    'writtenAt': Timestamp.parse('2024-03-01T10:00:00.000Z'),
  });
  await firestore.doc('user/alice/note/second').set({
    'title': 'Second note',
    'body': 'Edited like any other document.',
  });

  for (var index = 1; index <= 3; index++) {
    await firestore.doc('event/event_$index').set({
      'kind': index.isEven ? 'stopped' : 'started',
      'at': Timestamp.fromMillisecondsSinceEpoch(
        DateTime.utc(2024, 1, index).millisecondsSinceEpoch,
      ),
      'index': index,
    });
  }
}
