import 'dart:async';
import 'dart:math';

import 'package:tekartik_firebase/firebase_mixin.dart';
import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_firestore/firestore_mixin.dart';

import '../rules/rules_builder.dart';
import 'rules_data_utils.dart';
import 'rules_evaluator.dart';

/// Thrown by a [RulesEnforcedFirestore] when the rules deny an operation
/// (code [FirestoreErrorCode.permissionDenied], like a real backend).
class FirestoreRulesPermissionDeniedException extends FirestoreException {
  /// The evaluated request.
  final RulesRequest request;

  /// The decision, with its trace.
  final RulesDecision decision;

  /// Creates the exception for [request] denied by [decision].
  FirestoreRulesPermissionDeniedException(this.request, this.decision)
    : super(
        FirestoreErrorCode.permissionDenied,
        'Missing or insufficient permissions ($request)',
        details: decision,
      );

  @override
  String toString() =>
      'FirestoreRulesPermissionDeniedException($request)\n$decision';
}

/// Builds the [FirestoreRulesAuth] of a signed in [user], with the token
/// claims a real id token carries plus [customClaims].
FirestoreRulesAuth firestoreRulesAuthFromUser(
  User user, {
  Map<String, Object?>? customClaims,
}) {
  var email = user.email;
  return FirestoreRulesAuth(
    uid: user.uid,
    token: {
      ...?customClaims,
      'email': ?email,
      'email_verified': user.emailVerified,
      'name': ?user.displayName,
      'firebase': {
        'sign_in_provider': user.isAnonymous ? 'anonymous' : 'password',
        'identities': {
          if (email != null) 'email': [email],
        },
      },
    },
  );
}

/// Simulates the security rules on top of any [Firestore] implementation
/// (typically the in-memory one), so that access tests run without the
/// emulator.
///
/// The simulator holds the [rules], the current auth ([getAuth]) and the
/// custom claims; [enforce] wraps a [Firestore] into a rules enforced one, the
/// wrapped instance itself remains the admin access that bypasses the rules
/// (the way the emulator owner token does).
class FirestoreRulesSimulator {
  FirestoreRules _rules;
  late RulesEvaluator _evaluator;

  /// Returns the current user, null when signed out.
  FirestoreRulesAuth? Function() getAuth;

  /// Prints every decision when true.
  bool debug;

  /// Custom claims by user id, merged in the token when the auth comes from
  /// a [FirebaseAuth] user (see [bindAuth] and [setCustomUserClaims]).
  final customClaims = <String, Map<String, Object?>>{};

  /// Max distinct documents accessed per single document request.
  final int accessCallLimit;

  /// Creates a simulator for [rules].
  ///
  /// The user comes from [getAuth] when given, or from [auth]'s current user
  /// (see [bindAuth]); with neither, every request is anonymous.
  FirestoreRulesSimulator({
    required FirestoreRules rules,
    FirestoreRulesAuth? Function()? getAuth,
    FirebaseAuth? auth,
    this.debug = false,
    this.accessCallLimit = 10,
  }) : _rules = rules,
       getAuth = getAuth ?? (() => null) {
    _evaluator = RulesEvaluator(rules, accessCallLimit: accessCallLimit);
    if (auth != null) {
      bindAuth(auth);
    }
  }

  /// The rules.
  FirestoreRules get rules => _rules;

  /// Replaces the rules (existing enforced instances use the new ones).
  set rules(FirestoreRules rules) {
    _rules = rules;
    _evaluator = RulesEvaluator(rules, accessCallLimit: accessCallLimit);
  }

  /// The evaluator of the current rules.
  RulesEvaluator get evaluator => _evaluator;

  /// Takes the user from [auth]'s current user (email, verified flag and the
  /// custom claims set through [setCustomUserClaims] end up in the token).
  void bindAuth(FirebaseAuth auth) {
    getAuth = () {
      var user = auth.currentUser;
      if (user == null) {
        return null;
      }
      return firestoreRulesAuthFromUser(
        user,
        customClaims: customClaims[user.uid],
      );
    };
  }

  /// Sets the custom claims of [uid] (`request.auth.token.<claim>`), null
  /// clears them.
  void setCustomUserClaims(String uid, Map<String, Object?>? claims) {
    if (claims == null) {
      customClaims.remove(uid);
    } else {
      customClaims[uid] = Map<String, Object?>.from(claims);
    }
  }

  /// Wraps [firestore] into a rules enforced instance.
  RulesEnforcedFirestore enforce(Firestore firestore) =>
      RulesEnforcedFirestore(simulator: this, firestore: firestore);

  /// Wraps [firestoreService] into a service handing out rules enforced
  /// instances.
  RulesEnforcedFirestoreService enforceService(
    FirestoreService firestoreService,
  ) => RulesEnforcedFirestoreService(
    simulator: this,
    firestoreService: firestoreService,
  );

  /// Evaluates [request], throwing [FirestoreRulesPermissionDeniedException]
  /// when denied.
  Future<void> check(RulesRequest request, RulesDocumentReader reader) async {
    var decision = await _evaluator.evaluate(request, reader);
    if (debug) {
      // ignore: avoid_print
      print('[rules] $request: $decision');
    }
    if (!decision.allowed) {
      throw FirestoreRulesPermissionDeniedException(request, decision);
    }
  }
}

/// Reads through a plain [Firestore] (outside transactions).
class _FirestoreReader implements RulesDocumentReader {
  final Firestore firestore;

  _FirestoreReader(this.firestore);

  @override
  Future<Map<String, Object?>?> read(String path) async {
    var snapshot = await firestore.doc(path).get();
    return snapshot.exists ? snapshot.data : null;
  }
}

/// Reads through a transaction.
class _TransactionReader implements RulesDocumentReader {
  final Firestore firestore;
  final Transaction transaction;

  _TransactionReader(this.firestore, this.transaction);

  @override
  Future<Map<String, Object?>?> read(String path) async {
    var snapshot = await transaction.get(firestore.doc(path));
    return snapshot.exists ? snapshot.data : null;
  }
}

/// A [Firestore] checking every operation against the simulator rules before
/// forwarding it to the wrapped [firestore].
class RulesEnforcedFirestore
    with
        FirebaseAppProductMixin<Firestore>,
        FirestoreDefaultMixin,
        FirestoreMixin
    implements Firestore {
  /// The simulator (rules and auth).
  final FirestoreRulesSimulator simulator;

  /// The wrapped instance, not subject to the rules.
  final Firestore firestore;

  /// The service, created lazily unless given.
  late final RulesEnforcedFirestoreService enforcedService;

  /// Creates a rules enforced firestore over [firestore].
  RulesEnforcedFirestore({
    required this.simulator,
    required this.firestore,
    RulesEnforcedFirestoreService? service,
  }) {
    assert(
      firestore is! RulesEnforcedFirestore,
      'Cannot enforce rules on an already enforced firestore',
    );
    enforcedService =
        service ??
        RulesEnforcedFirestoreService(
          simulator: simulator,
          firestoreService: firestore.service,
        );
  }

  RulesDocumentReader get _reader => _FirestoreReader(firestore);

  @override
  FirebaseApp get app => firestore.app;

  @override
  FirestoreService get service => enforcedService;

  @override
  WriteBatch batch() => RulesEnforcedWriteBatch(this);

  @override
  CollectionReference collection(String path) =>
      RulesEnforcedCollectionReference(firestore.collection(path), this);

  @override
  DocumentReference doc(String path) =>
      RulesEnforcedDocumentReference(firestore.doc(path), this);

  @override
  Query collectionGroup(String collectionId) {
    throw UnsupportedError(
      'collectionGroup is not supported by the rules simulator',
    );
  }

  @override
  Future<List<CollectionReference>> listCollections() =>
      firestore.listCollections();

  @override
  bool get supportsTransaction => firestore.supportsTransaction;

  @override
  Future<T> runTransaction<T>(
    FutureOr<T> Function(Transaction transaction) action,
  ) {
    return firestore.runTransaction((transaction) async {
      var enforced = RulesEnforcedTransaction(transaction, this);
      var result = await action(enforced);
      await enforced.flush();
      return result;
    });
  }

  /// Checks a single document read of [path], [snapshot] being the delegate
  /// snapshot.
  Future<void> checkGet(
    String path,
    DocumentSnapshot snapshot, {
    RulesDocumentReader? reader,
    bool multi = false,
  }) {
    return simulator.check(
      RulesRequest(
        method: RulesMethod.get,
        path: path,
        auth: simulator.getAuth(),
        resourceData: snapshot.exists ? snapshot.data : null,
        multi: multi,
      ),
      reader ?? _reader,
    );
  }

  /// Checks a query on the collection [path].
  Future<void> checkList(String path) {
    return simulator.check(
      RulesRequest(
        method: RulesMethod.list,
        path: path,
        auth: simulator.getAuth(),
        multi: true,
      ),
      _reader,
    );
  }

  /// Checks a write, [existing] being the current document (null when
  /// missing).
  Future<void> _checkWrite(
    _WriteOp op,
    Map<String, Object?>? existing, {
    RulesDocumentReader? reader,
    bool multi = false,
  }) {
    RulesMethod method;
    Map<String, Object?>? requestResourceData;
    switch (op.type) {
      case _WriteType.set:
        method = existing == null ? RulesMethod.create : RulesMethod.update;
        requestResourceData = computeRequestResourceData(
          existing: existing,
          data: op.data!,
          merge: op.options?.merge ?? false,
        );
      case _WriteType.update:
        method = RulesMethod.update;
        requestResourceData = computeRequestResourceData(
          existing: existing,
          data: op.data!,
          update: true,
        );
      case _WriteType.delete:
        method = RulesMethod.delete;
    }
    return simulator.check(
      RulesRequest(
        method: method,
        path: op.path,
        auth: simulator.getAuth(),
        resourceData: existing,
        requestResourceData: requestResourceData,
        multi: multi,
      ),
      reader ?? _reader,
    );
  }

  Future<Map<String, Object?>?> _readExisting(String path) async {
    var snapshot = await firestore.doc(path).get();
    return snapshot.exists ? snapshot.data : null;
  }
}

enum _WriteType { set, update, delete }

class _WriteOp {
  final _WriteType type;
  final String path;
  final Map<String, Object?>? data;
  final SetOptions? options;

  _WriteOp(this.type, this.path, {this.data, this.options});
}

/// A rules enforced document reference.
class RulesEnforcedDocumentReference
    with
        DocumentReferenceDefaultMixin,
        DocumentReferenceMixin,
        PathReferenceMixin
    implements DocumentReference, FirestorePathReference {
  /// The wrapped reference.
  final DocumentReference ref;

  /// The enforced firestore.
  final RulesEnforcedFirestore enforcedFirestore;

  /// Creates a wrapper of [ref].
  RulesEnforcedDocumentReference(this.ref, this.enforcedFirestore);

  @override
  Firestore get firestore => enforcedFirestore;

  @override
  String get path => ref.path;

  @override
  Future<DocumentSnapshot> get() async {
    var snapshot = await ref.get();
    await enforcedFirestore.checkGet(path, snapshot);
    return RulesEnforcedDocumentSnapshot(snapshot, enforcedFirestore);
  }

  @override
  Stream<DocumentSnapshot> onSnapshot({bool includeMetadataChanges = false}) {
    return Stream.fromFuture(get()).asyncExpand(
      (_) => ref
          .onSnapshot(includeMetadataChanges: includeMetadataChanges)
          .map(
            (snapshot) =>
                RulesEnforcedDocumentSnapshot(snapshot, enforcedFirestore),
          ),
    );
  }

  Future<void> _write(_WriteOp op) async {
    var existing = await enforcedFirestore._readExisting(path);
    await enforcedFirestore._checkWrite(op, existing);
  }

  @override
  Future<void> set(Map<String, Object?> data, [SetOptions? options]) async {
    await _write(_WriteOp(_WriteType.set, path, data: data, options: options));
    await ref.set(data, options);
  }

  @override
  Future<void> update(Map<String, Object?> data) async {
    await _write(_WriteOp(_WriteType.update, path, data: data));
    await ref.update(data);
  }

  @override
  Future<void> delete() async {
    await _write(_WriteOp(_WriteType.delete, path));
    await ref.delete();
  }

  @override
  Future<List<CollectionReference>> listCollections() async {
    var collections = await ref.listCollections();
    return collections
        .map(
          (collection) =>
              RulesEnforcedCollectionReference(collection, enforcedFirestore),
        )
        .toList();
  }
}

const _autoIdChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random();

String _autoId() => List.generate(
  20,
  (_) => _autoIdChars[_random.nextInt(_autoIdChars.length)],
).join();

/// A rules enforced query.
class RulesEnforcedQuery
    with QueryDefaultMixin, FirestoreQueryExecutorMixin
    implements Query {
  /// The wrapped query.
  final Query query;

  /// The collection queried.
  late final RulesEnforcedCollectionReference collectionRef;

  /// Creates a wrapper of [query] on [collectionRef] (null only for the
  /// collection reference itself, which sets it in its constructor).
  RulesEnforcedQuery(
    this.query,
    RulesEnforcedCollectionReference? collectionRef,
  ) {
    if (collectionRef != null) {
      this.collectionRef = collectionRef;
    }
  }

  RulesEnforcedFirestore get _enforcedFirestore =>
      collectionRef.enforcedFirestore;

  @override
  Firestore get firestore => _enforcedFirestore;

  RulesEnforcedQuery _wrap(Query query) =>
      RulesEnforcedQuery(query, collectionRef);

  @override
  Future<QuerySnapshot> get() async {
    await _enforcedFirestore.checkList(collectionRef.path);
    return RulesEnforcedQuerySnapshot(await query.get(), _enforcedFirestore);
  }

  @override
  Stream<QuerySnapshot> onSnapshot({bool includeMetadataChanges = false}) {
    return Stream.fromFuture(
      _enforcedFirestore.checkList(collectionRef.path),
    ).asyncExpand(
      (_) => query
          .onSnapshot(includeMetadataChanges: includeMetadataChanges)
          .map(
            (snapshot) =>
                RulesEnforcedQuerySnapshot(snapshot, _enforcedFirestore),
          ),
    );
  }

  @override
  Future<int> count() async {
    await _enforcedFirestore.checkList(collectionRef.path);
    return query.count();
  }

  @override
  AggregateQuery aggregate(List<AggregateField> fields) =>
      _RulesEnforcedAggregateQuery(query.aggregate(fields), this);

  @override
  Query endAt({DocumentSnapshot? snapshot, List<Object?>? values}) =>
      _wrap(query.endAt(snapshot: _unwrap(snapshot), values: values));

  @override
  Query endBefore({DocumentSnapshot? snapshot, List<Object?>? values}) =>
      _wrap(query.endBefore(snapshot: _unwrap(snapshot), values: values));

  @override
  Query startAfter({DocumentSnapshot? snapshot, List<Object?>? values}) =>
      _wrap(query.startAfter(snapshot: _unwrap(snapshot), values: values));

  @override
  Query startAt({DocumentSnapshot? snapshot, List<Object?>? values}) =>
      _wrap(query.startAt(snapshot: _unwrap(snapshot), values: values));

  @override
  Query limit(int limit) => _wrap(query.limit(limit));

  @override
  Query orderBy(String key, {bool? descending}) =>
      _wrap(query.orderBy(key, descending: descending));

  @override
  Query select(List<String> keyPaths) => _wrap(query.select(keyPaths));

  @override
  Query where(
    String fieldPath, {
    Object? isEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object>? arrayContainsAny,
    List<Object>? whereIn,
    bool? isNull,
  }) => _wrap(
    query.where(
      fieldPath,
      isEqualTo: isEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      isNull: isNull,
    ),
  );

  static DocumentSnapshot? _unwrap(DocumentSnapshot? snapshot) =>
      snapshot is RulesEnforcedDocumentSnapshot ? snapshot.snapshot : snapshot;
}

class _RulesEnforcedAggregateQuery implements AggregateQuery {
  final AggregateQuery aggregateQuery;
  final RulesEnforcedQuery query;

  _RulesEnforcedAggregateQuery(this.aggregateQuery, this.query);

  @override
  Future<AggregateQuerySnapshot> get() async {
    await query._enforcedFirestore.checkList(query.collectionRef.path);
    return aggregateQuery.get();
  }
}

/// A rules enforced collection reference.
class RulesEnforcedCollectionReference extends RulesEnforcedQuery
    with CollectionReferenceMixin, PathReferenceMixin
    implements CollectionReference, FirestorePathReference {
  /// The enforced firestore.
  final RulesEnforcedFirestore enforcedFirestore;

  /// The wrapped reference.
  CollectionReference get ref => query as CollectionReference;

  /// Creates a wrapper of [ref].
  RulesEnforcedCollectionReference(
    CollectionReference ref,
    this.enforcedFirestore,
  ) : super(ref, null) {
    collectionRef = this;
  }

  @override
  Firestore get firestore => enforcedFirestore;

  @override
  String get path => ref.path;

  @override
  Future<DocumentReference> add(Map<String, Object?> data) async {
    // The id is generated here so that the create rule can be checked on the
    // full document path before writing.
    var docRef = doc(_autoId());
    await docRef.set(data);
    return docRef;
  }
}

/// A rules enforced document snapshot (its ref is enforced too).
class RulesEnforcedDocumentSnapshot
    with DocumentSnapshotMixin
    implements DocumentSnapshot {
  /// The wrapped snapshot.
  final DocumentSnapshot snapshot;

  /// The enforced firestore.
  final RulesEnforcedFirestore enforcedFirestore;

  /// Creates a wrapper of [snapshot].
  RulesEnforcedDocumentSnapshot(this.snapshot, this.enforcedFirestore);

  @override
  Timestamp? get createTime => snapshot.createTime;

  @override
  Map<String, Object?> get data => snapshot.data;

  @override
  bool get exists => snapshot.exists;

  @override
  DocumentReference get ref =>
      RulesEnforcedDocumentReference(snapshot.ref, enforcedFirestore);

  @override
  Timestamp? get updateTime => snapshot.updateTime;

  @override
  SnapshotMetadata get metadata => snapshot.metadata;
}

/// A rules enforced query snapshot.
class RulesEnforcedQuerySnapshot implements QuerySnapshot {
  /// The wrapped snapshot.
  final QuerySnapshot snapshot;

  /// The enforced firestore.
  final RulesEnforcedFirestore enforcedFirestore;

  /// Creates a wrapper of [snapshot].
  RulesEnforcedQuerySnapshot(this.snapshot, this.enforcedFirestore);

  @override
  List<DocumentSnapshot> get docs => snapshot.docs
      .map((doc) => RulesEnforcedDocumentSnapshot(doc, enforcedFirestore))
      .toList();

  @override
  List<DocumentChange> get documentChanges => snapshot.documentChanges
      .map((change) => _RulesEnforcedDocumentChange(change, enforcedFirestore))
      .toList();
}

class _RulesEnforcedDocumentChange implements DocumentChange {
  final DocumentChange change;
  final RulesEnforcedFirestore enforcedFirestore;

  _RulesEnforcedDocumentChange(this.change, this.enforcedFirestore);

  @override
  DocumentSnapshot get document =>
      RulesEnforcedDocumentSnapshot(change.document, enforcedFirestore);

  @override
  int get newIndex => change.newIndex;

  @override
  int get oldIndex => change.oldIndex;

  @override
  DocumentChangeType get type => change.type;
}

DocumentReference _unwrapRef(DocumentReference ref) =>
    ref is RulesEnforcedDocumentReference ? ref.ref : ref;

/// A rules enforced write batch: writes are buffered, checked against the
/// state before the batch on [commit], then forwarded.
class RulesEnforcedWriteBatch implements WriteBatch {
  /// The enforced firestore.
  final RulesEnforcedFirestore enforcedFirestore;
  final _ops = <_WriteOp>[];

  /// Creates a batch.
  RulesEnforcedWriteBatch(this.enforcedFirestore);

  @override
  void delete(DocumentReference ref) {
    _ops.add(_WriteOp(_WriteType.delete, ref.path));
  }

  @override
  void set(
    DocumentReference ref,
    Map<String, Object?> data, [
    SetOptions? options,
  ]) {
    _ops.add(_WriteOp(_WriteType.set, ref.path, data: data, options: options));
  }

  @override
  void update(DocumentReference ref, Map<String, Object?> data) {
    _ops.add(_WriteOp(_WriteType.update, ref.path, data: data));
  }

  @override
  Future<void> commit() async {
    for (var op in _ops) {
      var existing = await enforcedFirestore._readExisting(op.path);
      await enforcedFirestore._checkWrite(op, existing, multi: true);
    }
    var batch = enforcedFirestore.firestore.batch();
    for (var op in _ops) {
      var ref = enforcedFirestore.firestore.doc(op.path);
      switch (op.type) {
        case _WriteType.set:
          batch.set(ref, op.data!, op.options);
        case _WriteType.update:
          batch.update(ref, op.data!);
        case _WriteType.delete:
          batch.delete(ref);
      }
    }
    await batch.commit();
  }
}

/// A rules enforced transaction: reads are checked as they happen, writes
/// are buffered and checked against the state before the transaction when
/// the action completes (see [flush]).
class RulesEnforcedTransaction with TransactionMixin implements Transaction {
  /// The wrapped transaction.
  final Transaction transaction;

  /// The enforced firestore.
  final RulesEnforcedFirestore enforcedFirestore;
  final _ops = <_WriteOp>[];

  /// Creates a wrapper of [transaction].
  RulesEnforcedTransaction(this.transaction, this.enforcedFirestore);

  RulesDocumentReader get _reader =>
      _TransactionReader(enforcedFirestore.firestore, transaction);

  @override
  Future<DocumentSnapshot> get(DocumentReference documentRef) async {
    var snapshot = await transaction.get(_unwrapRef(documentRef));
    await enforcedFirestore.checkGet(
      documentRef.path,
      snapshot,
      reader: _reader,
      multi: true,
    );
    return RulesEnforcedDocumentSnapshot(snapshot, enforcedFirestore);
  }

  @override
  void delete(DocumentReference documentRef) {
    _ops.add(_WriteOp(_WriteType.delete, documentRef.path));
  }

  @override
  void set(
    DocumentReference documentRef,
    Map<String, Object?> data, [
    SetOptions? options,
  ]) {
    _ops.add(
      _WriteOp(_WriteType.set, documentRef.path, data: data, options: options),
    );
  }

  @override
  void update(DocumentReference documentRef, Map<String, Object?> data) {
    _ops.add(_WriteOp(_WriteType.update, documentRef.path, data: data));
  }

  /// Checks and applies the buffered writes.
  Future<void> flush() async {
    var reader = _reader;
    for (var op in _ops) {
      var existing = await reader.read(op.path);
      await enforcedFirestore._checkWrite(
        op,
        existing,
        reader: reader,
        multi: true,
      );
    }
    for (var op in _ops) {
      var ref = enforcedFirestore.firestore.doc(op.path);
      switch (op.type) {
        case _WriteType.set:
          transaction.set(ref, op.data!, op.options);
        case _WriteType.update:
          transaction.update(ref, op.data!);
        case _WriteType.delete:
          transaction.delete(ref);
      }
    }
    _ops.clear();
  }
}

/// A [FirestoreService] handing out [RulesEnforcedFirestore] instances.
class RulesEnforcedFirestoreService
    with FirebaseProductServiceMixin<Firestore>, FirestoreServiceDefaultMixin
    implements FirestoreService {
  /// The simulator.
  final FirestoreRulesSimulator simulator;

  /// The wrapped service.
  final FirestoreService firestoreService;

  /// Creates a service wrapping [firestoreService].
  RulesEnforcedFirestoreService({
    required this.simulator,
    required this.firestoreService,
  });

  @override
  Firestore firestore(App app) => getInstance(app, () {
    return RulesEnforcedFirestore(
      simulator: simulator,
      firestore: firestoreService.firestore(app),
      service: this,
    );
  });

  @override
  bool get supportsDocumentSnapshotTime =>
      firestoreService.supportsDocumentSnapshotTime;

  @override
  bool get supportsFieldValueArray => firestoreService.supportsFieldValueArray;

  @override
  bool get supportsQuerySelect => firestoreService.supportsQuerySelect;

  @override
  bool get supportsQuerySnapshotCursor =>
      firestoreService.supportsQuerySnapshotCursor;

  @override
  bool get supportsTimestamps => firestoreService.supportsTimestamps;

  @override
  bool get supportsTimestampsInSnapshots =>
      firestoreService.supportsTimestampsInSnapshots;

  @override
  bool get supportsTrackChanges => firestoreService.supportsTrackChanges;

  @override
  bool get supportsAggregateQueries =>
      firestoreService.supportsAggregateQueries;

  @override
  bool get supportsBlobs => firestoreService.supportsBlobs;

  @override
  bool get supportsListCollections => firestoreService.supportsListCollections;

  @override
  bool get supportsVectorValue => firestoreService.supportsVectorValue;
}
