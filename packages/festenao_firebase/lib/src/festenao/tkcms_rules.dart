import 'package:tkcms_common/tkcms_firestore.dart';

import '../rules/rules_builder.dart';
import '../rules/rules_expression.dart';

/// The `read` access field name of a `TkCmsFsUserAccess` document.
const tkCmsRulesReadAccess = 'read';

/// The `write` access field name.
const tkCmsRulesWriteAccess = 'write';

/// The `admin` access field name.
const tkCmsRulesAdminAccess = 'admin';

/// The `user_prv` collection of per user private data.
const tkCmsRulesUserPrvCollectionId = 'user_prv';

/// The `user_access` collection of app level user rights.
const tkCmsRulesUserAccessCollectionId = 'user_access';

/// The `public/get` world readable documents.
const tkCmsRulesPublicGetPath = 'public/get';

/// The `creatorUserId` field of an entity created without a backend.
const tkCmsRulesCreatorUserIdField = 'creatorUserId';

/// The `inviteId` field of an access document created from an invite.
const tkCmsRulesInviteIdField = 'inviteId';

/// The `entityId` field of an invite.
const tkCmsRulesEntityIdField = 'entityId';

/// The `userAccess` field of an invite.
const tkCmsRulesUserAccessField = 'userAccess';

/// How the entity document and its data are written.
enum TkCmsEntityDataScope {
  /// The entity document itself (read: read access, write: admin access by
  /// default) plus its `data/{dataId}/**` subtree (read: read access, write:
  /// write access). Other subcollections stay server only. This is the
  /// current shape of the api and no-api contexts.
  dataOnly,

  /// The whole `{entity}/{entityId}/**` subtree with a single rule (legacy
  /// festenao shape, `read, write: if write access`).
  all,
}

/// Where the public read flag applies.
enum TkCmsPublicReadScope {
  /// Only the `data/{dataId}/**` subtree (no-api context).
  dataOnly,

  /// The entity document and its whole subtree (full api context).
  all,
}

/// The nesting depth of an entity in the tkcms firestore layout.
///
/// Depth 0 is a top level entity (`/{entity}/{entityId}`), depth 1 an entity
/// under a top one (`/{top}/{topId}/{entity}/{entityId}`, festenao projects
/// under an app), depth 2 goes one level further
/// (`/{top}/{topId}/{sub}/{subId}/{entity}/{entityId}`), and so on.
///
/// Every function generated for a level is prefixed (`hasEntityAccess`,
/// `subHasEntityAccess`, `sub2HasEntityAccess`...) and takes the parent
/// wildcards as its first parameters.
class TkCmsRulesLevel {
  /// The depth, 0 for a top level entity.
  final int depth;

  /// Creates a level.
  const TkCmsRulesLevel(this.depth);

  /// The parent wildcard name pairs, e.g. `[('top', 'topId')]` at depth 1.
  List<(String, String)> get parentWildcards => [
    for (var i = 0; i < depth; i++)
      switch (i) {
        0 => ('top', 'topId'),
        1 => ('sub', 'subId'),
        _ => ('sub$i', 'sub${i}Id'),
      },
  ];

  /// The parent wildcard names flattened: `['top', 'topId', ...]`.
  List<String> get parentParams => [
    for (var pair in parentWildcards) ...[pair.$1, pair.$2],
  ];

  /// The parent pattern text: `''` at depth 0, `/{top}/{topId}` at depth 1.
  String get parentPattern =>
      [for (var pair in parentWildcards) '/{${pair.$1}}/{${pair.$2}}'].join();

  /// The function name prefix: `''`, `sub`, `sub2`...
  String get functionPrefix => switch (depth) {
    0 => '',
    1 => 'sub',
    _ => 'sub$depth',
  };

  /// [name] prefixed for this level (`hasEntityAccess` becomes
  /// `subHasEntityAccess` at depth 1).
  String functionName(String name) {
    var prefix = functionPrefix;
    if (prefix.isEmpty) {
      return name;
    }
    return '$prefix${name[0].toUpperCase()}${name.substring(1)}';
  }

  /// A pattern under the parent: `pattern('/{entity}/{entityId}')`.
  String pattern(String relative) => '$parentPattern$relative';

  /// The parent wildcard variables of [match] (which must be under a pattern
  /// built with [pattern]).
  List<RulesVar> parentVars(RulesMatch match) =>
      parentParams.map(match.v).toList();

  @override
  String toString() => 'level $depth';
}

/// The tkcms rule sets for one [level], added to the shared [tkCmsRules].
///
/// Every `add*` method appends one commented section to the rules file. The
/// generated functions are declared once, the first time they are needed.
class TkCmsEntityRules {
  /// The shared builder.
  final TkCmsFirestoreRules tkCmsRules;

  /// The level.
  final TkCmsRulesLevel level;

  final _functions = <String, RulesFunction>{};

  /// Creates the rule sets of [level].
  TkCmsEntityRules(this.tkCmsRules, this.level);

  /// The rules file.
  FirestoreRules get rules => tkCmsRules.rules;

  /// `signedIn()`.
  RulesExpr get signedIn => tkCmsRules.signedIn;

  /// `request.auth.uid`.
  RulesExpr get uid => requestAuthUid;

  RulesFunction _function(
    String name,
    List<String> params,
    Object? Function(RulesFunctionScope f) body,
  ) {
    var fullName = level.functionName(name);
    return _functions[fullName] ??= rules.function(fullName, [
      ...level.parentParams,
      ...params,
    ], body);
  }

  List<RulesVar> _parentParamsOf(RulesFunctionScope f) =>
      level.parentParams.map(f.param).toList();

  /// The access document path
  /// `<parent>/access/{entity}/entity_id/{entityId}/user_access/{userId}`.
  RulesPath userAccessPath(
    List<Object> parentVars,
    Object entity,
    Object entityId,
    Object userId,
  ) => docPath([
    ...parentVars,
    tkCmsFsEntityTypeAccessCollectionId,
    entity,
    tkCmsFsEntityIdCollectionId,
    entityId,
    tkCmsFsUserAccessCollectionId,
    userId,
  ]);

  /// The public access document path
  /// `<parent>/access/{entity}/entity_id/{entityId}/public_access/public`.
  RulesPath publicAccessPath(
    List<Object> parentVars,
    Object entity,
    Object entityId,
  ) => docPath([
    ...parentVars,
    tkCmsFsEntityTypeAccessCollectionId,
    entity,
    tkCmsFsEntityIdCollectionId,
    entityId,
    tkCmsPublicAccessFirestorePathPart,
    tkCmsPublicAccessPublicDocumentId,
  ]);

  /// `hasEntityAccess(<parent>, entity, entityId, userId, access)`: the user
  /// access document exists and its [access] field (`read`, `write` or
  /// `admin`) is true.
  RulesFunction get hasEntityAccessFunction => _function(
    'hasEntityAccess',
    ['entity', 'entityId', 'userId', 'access'],
    (f) {
      var doc = f.let(
        'doc',
        rulesGet(
          userAccessPath(
            _parentParamsOf(f),
            f.param('entity'),
            f.param('entityId'),
            f.param('userId'),
          ),
        ),
      );
      return doc.isNotNull & doc.data.get(f.param('access'), false).eq(true);
    },
  );

  RulesFunction _hasEntityAccessFunction(String access) {
    var name =
        'hasEntity${access[0].toUpperCase()}${access.substring(1)}Access';
    return _function(name, ['entity', 'entityId', 'userId'], (f) {
      return hasEntityAccessFunction.call([
        ..._parentParamsOf(f),
        f.param('entity'),
        f.param('entityId'),
        f.param('userId'),
        access,
      ]);
    });
  }

  /// `hasEntityAdminAccess(<parent>, entity, entityId, userId)`.
  RulesFunction get hasEntityAdminAccessFunction =>
      _hasEntityAccessFunction(tkCmsRulesAdminAccess);

  /// `hasEntityWriteAccess(<parent>, entity, entityId, userId)`.
  RulesFunction get hasEntityWriteAccessFunction =>
      _hasEntityAccessFunction(tkCmsRulesWriteAccess);

  /// `hasEntityReadAccess(<parent>, entity, entityId, userId)`.
  RulesFunction get hasEntityReadAccessFunction =>
      _hasEntityAccessFunction(tkCmsRulesReadAccess);

  /// `hasEntityPublicReadAccess(<parent>, entity, entityId)`: the public
  /// access document exists with `read: true`.
  RulesFunction get hasEntityPublicReadAccessFunction => _function(
    'hasEntityPublicReadAccess',
    ['entity', 'entityId'],
    (f) {
      var doc = f.let(
        'doc',
        rulesGet(
          publicAccessPath(
            _parentParamsOf(f),
            f.param('entity'),
            f.param('entityId'),
          ),
        ),
      );
      return doc.isNotNull & doc.data.get(tkCmsRulesReadAccess, false).eq(true);
    },
  );

  /// `entityCreatorUserIdMatches(<parent>, entity, entityId, userId)`: the
  /// entity document exists and its `creatorUserId` is [userId].
  RulesFunction get entityCreatorUserIdMatchesFunction => _function(
    'entityCreatorUserIdMatches',
    ['entity', 'entityId', 'userId'],
    (f) {
      var doc = f.let(
        'doc',
        rulesGet(
          docPath([
            ..._parentParamsOf(f),
            f.param('entity'),
            f.param('entityId'),
          ]),
        ),
      );
      return doc.isNotNull &
          doc.data
              .get(tkCmsRulesCreatorUserIdField, '__none__')
              .eq(f.param('userId'));
    },
  );

  /// `inviteMatchesInviteCode(<parent>, entity, userId, inviteCode)`: the
  /// user holds an admin `invite_access/{inviteCode}` document (standalone
  /// invite creation).
  RulesFunction get inviteMatchesInviteCodeFunction => _function(
    'inviteMatchesInviteCode',
    ['entity', 'userId', 'inviteCode'],
    (f) {
      var doc = f.let(
        'doc',
        rulesGet(
          docPath([
            ..._parentParamsOf(f),
            tkCmsFsEntityTypeAccessCollectionId,
            f.param('entity'),
            tkCmsFsUserIdCollectionId,
            f.param('userId'),
            tkCmsFsInviteAccessCollectionId,
            f.param('inviteCode'),
          ]),
        ),
      );
      return f.param('inviteCode').isNotNull &
          doc.isNotNull &
          doc.data.get(tkCmsRulesAdminAccess, false).eq(true);
    },
  );

  /// `accessMatchesInvite(<parent>, entity, entityId, inviteId)`: the invite
  /// grants admin access on the entity (standalone invite acceptance).
  RulesFunction get accessMatchesInviteFunction =>
      _function('accessMatchesInvite', ['entity', 'entityId', 'inviteId'], (f) {
        var doc = f.let(
          'doc',
          rulesGet(
            docPath([
              ..._parentParamsOf(f),
              tkCmsFsEntityTypeInviteCollectionId,
              f.param('entity'),
              tkCmsFsInviteIdCollectionId,
              f.param('inviteId'),
              tkCmsFsInviteEntityCollectionId,
              f.param('entityId'),
            ]),
          ),
        );
        return f.param('inviteId').isNotNull &
            doc.isNotNull &
            doc.data
                .get(tkCmsRulesUserAccessField, const <String, Object?>{})
                .get(tkCmsRulesAdminAccess, false)
                .eq(true);
      });

  /// `hasEntity<access>Access(<parent>, entity, entityId, request.auth.uid)`
  /// for the entity of [match] (a match under `/{entity}/{entityId}`).
  RulesExpr hasAccess(RulesMatch match, String access) {
    var function = switch (access) {
      tkCmsRulesAdminAccess => hasEntityAdminAccessFunction,
      tkCmsRulesWriteAccess => hasEntityWriteAccessFunction,
      tkCmsRulesReadAccess => hasEntityReadAccessFunction,
      _ => throw ArgumentError.value(access, 'access'),
    };
    return function.call([
      ...level.parentVars(match),
      match.v('entity'),
      match.v('entityId'),
      uid,
    ]);
  }

  /// `signedIn() && hasEntity<access>Access(...)`.
  RulesExpr signedInWithAccess(RulesMatch match, String access) =>
      signedIn & hasAccess(match, access);

  /// `hasEntityPublicReadAccess(<parent>, entity, entityId)` for [match].
  RulesExpr hasPublicReadAccess(RulesMatch match) =>
      hasEntityPublicReadAccessFunction.call([
        ...level.parentVars(match),
        match.v('entity'),
        match.v('entityId'),
      ]);

  void _section(String title) {
    rules.blankLine();
    rules.comment('\n$title\n');
  }

  /// The entity document and its data, members read, writers/admins write.
  ///
  /// With [TkCmsEntityDataScope.dataOnly] (default): the entity document is
  /// readable with read access and writable with admin access
  /// ([rootWriteAccess], `write` to relax it); `data/{dataId}/**` is readable
  /// with read access and writable with write access.
  ///
  /// With [TkCmsEntityDataScope.all]: one rule on `{entity}/{entityId}/**`,
  /// read with [allReadAccess] (default `read`, the legacy top level festenao
  /// rules used `write`) and write with write access.
  void addEntityRules({
    TkCmsEntityDataScope dataScope = TkCmsEntityDataScope.dataOnly,
    String rootWriteAccess = tkCmsRulesAdminAccess,
    String allReadAccess = tkCmsRulesReadAccess,
    String? title,
  }) {
    _section(title ?? 'Entity (${level.pattern('/{entity}/{entityId}')})');
    switch (dataScope) {
      case TkCmsEntityDataScope.dataOnly:
        rules.comment(
          'The entity document: members read it, ${rootWriteAccess}s write it.',
        );
        rules.match(level.pattern('/{entity}/{entityId}'), (m) {
          m.allow([
            RulesMethod.read,
          ], signedInWithAccess(m, tkCmsRulesReadAccess));
          m.allow([RulesMethod.write], signedInWithAccess(m, rootWriteAccess));
          m.blankLine();
          m.comment('Its data: members read it, writers write it.');
          m.match('/data/{dataId}/{document=**}', (d) {
            d.allow([
              RulesMethod.read,
            ], signedInWithAccess(d, tkCmsRulesReadAccess));
            d.allow([
              RulesMethod.write,
            ], signedInWithAccess(d, tkCmsRulesWriteAccess));
          });
        });
      case TkCmsEntityDataScope.all:
        rules.match(level.pattern('/{entity}/{entityId}/{document=**}'), (m) {
          if (allReadAccess == tkCmsRulesWriteAccess) {
            m.allow([
              RulesMethod.read,
              RulesMethod.write,
            ], signedInWithAccess(m, tkCmsRulesWriteAccess));
          } else {
            m.allow([RulesMethod.read], signedInWithAccess(m, allReadAccess));
            m.allow([
              RulesMethod.write,
            ], signedInWithAccess(m, tkCmsRulesWriteAccess));
          }
        });
    }
  }

  /// Any signed in user can read an invite it knows the id of.
  void addInviteReadRules() {
    _section(
      'Invite (${level.pattern('/invite/{entity}/invite_id/{inviteId}')})',
    );
    rules.match(
      level.pattern(
        '/$tkCmsFsEntityTypeInviteCollectionId/{entity}/$tkCmsFsInviteIdCollectionId/{inviteId}/$tkCmsFsInviteEntityCollectionId/{entityId}',
      ),
      (m) {
        m.allow([RulesMethod.read], signedIn);
      },
    );
  }

  /// Entity admins read and write the access documents of their entity (both
  /// the per entity and the per user index).
  void addAccessManageRules() {
    _section('Access manage (admins)');
    rules.match(
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsEntityIdCollectionId/{entityId}/$tkCmsFsUserAccessCollectionId/{userId}',
      ),
      (m) {
        m.allow([
          RulesMethod.read,
          RulesMethod.write,
        ], signedInWithAccess(m, tkCmsRulesAdminAccess));
      },
    );
    rules.match(
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}/$tkCmsFsEntityAccessCollectionId/{entityId}',
      ),
      (m) {
        m.allow([
          RulesMethod.read,
          RulesMethod.write,
        ], signedInWithAccess(m, tkCmsRulesAdminAccess));
      },
    );
  }

  /// A user reads its own access rows.
  ///
  /// By default one rule on the whole
  /// `access/{entity}/user_id/{userId}/**` tree. [legacy] adds the three
  /// separate rules of the older files instead (the per entity user_access
  /// document, the entity_access row and the user_id document).
  void addAccessUserReadRules({bool legacy = false}) {
    _section('Access user read (own rows)');
    var ownRow = requestAuthUid.eq(const RulesVar('userId'));
    if (legacy) {
      rules.match(
        level.pattern(
          '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsEntityIdCollectionId/{entityId}/$tkCmsFsUserAccessCollectionId/{userId}',
        ),
        (m) => m.allow([RulesMethod.read], ownRow),
      );
      rules.match(
        level.pattern(
          '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}/$tkCmsFsEntityAccessCollectionId/{entityId}',
        ),
        (m) => m.allow([RulesMethod.read], ownRow),
      );
      rules.match(
        level.pattern(
          '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}',
        ),
        (m) => m.allow([RulesMethod.read], ownRow),
      );
    } else {
      rules.match(
        level.pattern(
          '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}/{document=**}',
        ),
        (m) => m.allow([RulesMethod.read], signedIn & ownRow),
      );
    }
  }

  /// A user gets and deletes (leaves) its own access document of an entity
  /// (`get` and not `read`: on a list the userId wildcard is unbound).
  void addAccessSelfRules() {
    _section('Access user self (get and leave)');
    rules.comment(
      '`get` and not `read`: on a `list` the {userId} wildcard is unbound, and\n'
      'comparing it is an evaluation error, which denies the whole query.',
    );
    var ownRow = signedIn & requestAuthUid.eq(const RulesVar('userId'));
    rules.match(
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsEntityIdCollectionId/{entityId}/$tkCmsFsUserAccessCollectionId/{userId}',
      ),
      (m) {
        m.allow([RulesMethod.get], ownRow);
        m.allow([RulesMethod.delete], ownRow);
      },
    );
    rules.match(
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}/$tkCmsFsEntityAccessCollectionId/{entityId}',
      ),
      (m) => m.allow([RulesMethod.delete], ownRow),
    );
  }

  /// Standalone (no backend) invites by code: a user holding an admin
  /// `invite_access/{inviteCode}` creates invites, any signed in user reads
  /// and deletes them, and an access document naming an admin invite can be
  /// created by anyone (the invite id is the capability).
  void addStandaloneInviteRules() {
    _section('Standalone invites (no backend)');
    rules.comment(
      'access/{entity}/user_id/{userId}/invite_access/{inviteCode} - allows creating invites\n'
      'invite/{entity}/invite_id/{inviteId}/invite_entity/{entityId} - the invite\n'
      'access documents created with an inviteId matching an admin invite',
    );
    var invitePattern = level.pattern(
      '/$tkCmsFsEntityTypeInviteCollectionId/{entity}/$tkCmsFsInviteIdCollectionId/{document=**}',
    );
    rules.match(invitePattern, (m) {
      m.allow(
        [RulesMethod.create],
        inviteMatchesInviteCodeFunction.call([
          ...level.parentVars(m),
          m.v('entity'),
          uid,
          requestResourceData.member(tkCmsFsInviteCodeKey),
        ]),
      );
      m.allow([
        RulesMethod.read,
      ], signedIn & resourceData.member(tkCmsRulesEntityIdField).isNotNull);
      m.allow([RulesMethod.delete], signedIn);
    });
    for (var pattern in [
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsEntityIdCollectionId/{entityId}/$tkCmsFsUserAccessCollectionId/{document}',
      ),
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}/$tkCmsFsEntityAccessCollectionId/{entityId}',
      ),
    ]) {
      rules.match(pattern, (m) {
        m.allow(
          [RulesMethod.create],
          accessMatchesInviteFunction.call([
            ...level.parentVars(m),
            m.v('entity'),
            m.v('entityId'),
            requestResourceData.member(tkCmsRulesInviteIdField),
          ]),
        );
        m.allow([
          RulesMethod.read,
          RulesMethod.write,
        ], signedInWithAccess(m, tkCmsRulesAdminAccess));
      });
    }
    rules.match(invitePattern, (m) {
      m.allow(
        [RulesMethod.write],
        signedIn &
            hasEntityAdminAccessFunction.call([
              ...level.parentVars(m),
              m.v('entity'),
              requestResourceData.member(tkCmsRulesEntityIdField),
              uid,
            ]),
      );
    });
  }

  /// Standalone (no backend) entity creation: a signed in user creates an
  /// entity naming itself as `creatorUserId`, gets it, and then creates its
  /// own access documents as long as the entity's `creatorUserId` matches.
  void addCreatorRules() {
    _section('Entity creator (standalone, no backend)');
    rules.comment(
      'A `get()` reads the state before the current write, so the entity\n'
      'document has to be committed before its access documents are written.',
    );
    rules.match(level.pattern('/{entity}/{entityId}'), (m) {
      m.allow(
        [RulesMethod.create],
        signedIn &
            requestResourceData
                .get(tkCmsRulesCreatorUserIdField, '__none__')
                .eq(uid),
      );
      m.allow([RulesMethod.get], signedIn);
    });
    for (var pattern in [
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsEntityIdCollectionId/{entityId}/$tkCmsFsUserAccessCollectionId/{userId}',
      ),
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsUserIdCollectionId/{userId}/$tkCmsFsEntityAccessCollectionId/{entityId}',
      ),
    ]) {
      rules.match(pattern, (m) {
        m.allow(
          [RulesMethod.create],
          signedIn &
              entityCreatorUserIdMatchesFunction.call([
                ...level.parentVars(m),
                m.v('entity'),
                m.v('entityId'),
                uid,
              ]),
        );
      });
    }
  }

  /// Public read flag: anyone (signed out included) reads a public entity.
  ///
  /// [scope] selects what the flag opens; the flag document itself is
  /// readable by anyone and, when [adminWrite] is true, writable by entity
  /// admins (a server only deployment sets it to false).
  void addPublicAccessRules({
    TkCmsPublicReadScope scope = TkCmsPublicReadScope.all,
    bool adminWrite = true,
  }) {
    _section('Public access (${level.pattern('/{entity}/{entityId}')})');
    rules.comment(
      'Public access flag: access/{entity}/entity_id/{entityId}/public_access/public {read: true}',
    );
    switch (scope) {
      case TkCmsPublicReadScope.dataOnly:
        rules.match(
          level.pattern('/{entity}/{entityId}/data/{dataId}/{document=**}'),
          (m) => m.allow([RulesMethod.read], hasPublicReadAccess(m)),
        );
      case TkCmsPublicReadScope.all:
        rules.match(
          level.pattern('/{entity}/{entityId}'),
          (m) => m.allow([RulesMethod.read], hasPublicReadAccess(m)),
        );
        rules.match(
          level.pattern('/{entity}/{entityId}/{document=**}'),
          (m) => m.allow([RulesMethod.read], hasPublicReadAccess(m)),
        );
    }
    rules.comment(
      'Anyone can check the flag${adminWrite ? ', entity admins set it' : ''}',
    );
    rules.match(
      level.pattern(
        '/$tkCmsFsEntityTypeAccessCollectionId/{entity}/$tkCmsFsEntityIdCollectionId/{entityId}/$tkCmsPublicAccessFirestorePathPart/{document}',
      ),
      (m) {
        m.allow([RulesMethod.read], true);
        if (adminWrite) {
          m.allow([
            RulesMethod.write,
          ], signedInWithAccess(m, tkCmsRulesAdminAccess));
        }
      },
    );
  }

  /// Per user private data: `<parent>/user_prv/{userId}/**` is readable and
  /// writable by its user only.
  void addUserPrvRules() {
    _section('Per user private data');
    rules.match(
      level.pattern('/$tkCmsRulesUserPrvCollectionId/{userId}/{document=**}'),
      (m) => m.allow([
        RulesMethod.read,
        RulesMethod.write,
      ], signedIn & requestAuthUid.eq(m.v('userId'))),
    );
  }

  /// Per user private document under an entity:
  /// `<parent>/{entity}/{entityId}/user_prv/{userId}` (legacy festenao).
  void addEntityUserPrvRules() {
    _section('Per user private data (entity)');
    rules.match(
      level.pattern(
        '/{entity}/{entityId}/$tkCmsRulesUserPrvCollectionId/{userId}',
      ),
      (m) => m.allow([
        RulesMethod.read,
        RulesMethod.write,
      ], signedIn & requestAuthUid.eq(m.v('userId'))),
    );
  }

  /// App level user rights `<parent>/user_access/{userId}`: readable by
  /// their owner, never client writable.
  void addUserAccessRules() {
    _section('User rights (readable by their owner, server written)');
    rules.match(
      level.pattern('/$tkCmsRulesUserAccessCollectionId/{userId}'),
      (m) => m.allow([
        RulesMethod.read,
      ], signedIn & requestAuthUid.eq(m.v('userId'))),
    );
  }

  /// World readable documents under `<parent>/public/get/**` (get only, no
  /// list).
  void addPublicGetRules() {
    rules.comment('Public get documents');
    rules.match(
      level.pattern('/$tkCmsRulesPublicGetPath/{document=**}'),
      (m) => m.allow([RulesMethod.get], true),
    );
  }
}

/// A firestore rules file built from the tkcms rule sets.
///
/// ```dart
/// var tkCms = TkCmsFirestoreRules()..denyAll();
/// tkCms.level(1)
///   ..addEntityRules()
///   ..addAccessManageRules()
///   ..addUserPrvRules();
/// print(tkCms.rules.toRulesText());
/// ```
class TkCmsFirestoreRules {
  /// The rules file.
  final FirestoreRules rules;

  late final RulesFunction _signedInFunction;
  final _levels = <int, TkCmsEntityRules>{};

  /// Creates the builder, declaring `signedIn()`; [denyAll] adds the explicit
  /// deny everything block first.
  TkCmsFirestoreRules({FirestoreRules? rules, bool denyAll = false})
    : rules = rules ?? FirestoreRules() {
    if (denyAll) {
      this.rules.denyAll();
      this.rules.blankLine();
    }
    _signedInFunction = this.rules.function(
      'signedIn',
      [],
      (f) => requestAuth.isNotNull & requestAuthUid.isNotNull,
    );
  }

  /// `signedIn()`: `request.auth != null && request.auth.uid != null`.
  RulesExpr get signedIn => _signedInFunction.call([]);

  /// The rule sets of the entities at [depth] (0: `/{entity}/{entityId}`,
  /// 1: `/{top}/{topId}/{entity}/{entityId}`...).
  TkCmsEntityRules level(int depth) =>
      _levels[depth] ??= TkCmsEntityRules(this, TkCmsRulesLevel(depth));

  /// The rules file text.
  String toRulesText() => rules.toRulesText();
}
