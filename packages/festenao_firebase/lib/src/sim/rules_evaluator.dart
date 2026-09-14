import 'dart:async';

import 'package:collection/collection.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

import '../rules/rules_builder.dart';
import '../rules/rules_expression.dart';

/// An error raised while evaluating an expression (null dereference, unknown
/// member, type mismatch...). An `allow` whose condition raises is false.
class RulesEvalError implements Exception {
  /// What went wrong.
  final String message;

  /// Creates an evaluation error.
  RulesEvalError(this.message);

  @override
  String toString() => 'RulesEvalError: $message';
}

/// A path wildcard bound during a `list` request, where the document id is
/// not known: using it in an expression is an evaluation error, like in the
/// real engine.
class RulesUnbound {
  const RulesUnbound._();

  /// The singleton.
  static const instance = RulesUnbound._();

  @override
  String toString() => '<unbound>';
}

/// A path value (`/databases/x/documents/a/b`), the result of a path literal.
class RulesPathValue {
  /// The segments, without the leading `/`.
  final List<String> segments;

  /// Creates a path value.
  const RulesPathValue(this.segments);

  /// The document path relative to the documents root (throws if the path is
  /// not a `/databases/{db}/documents/...` document path).
  String get documentPath {
    if (segments.length < 3 ||
        segments[0] != 'databases' ||
        segments[2] != 'documents') {
      throw RulesEvalError('Not a document path: $this');
    }
    var docSegments = segments.sublist(3);
    if (docSegments.isEmpty || docSegments.length.isOdd) {
      throw RulesEvalError('Not a document path: $this');
    }
    return docSegments.join('/');
  }

  @override
  bool operator ==(Object other) =>
      other is RulesPathValue &&
      const ListEquality<String>().equals(segments, other.segments);

  @override
  int get hashCode => const ListEquality<String>().hash(segments);

  @override
  String toString() => '/${segments.join('/')}';
}

/// A document as seen by the rules: `resource`, `request.resource` and the
/// result of `get()`.
class RulesResourceValue {
  /// Document path relative to the documents root.
  final String path;

  /// The document fields.
  final Map<String, Object?> data;

  /// Creates a resource value.
  const RulesResourceValue(this.path, this.data);

  /// The document id.
  String get id => path.split('/').last;

  /// `__name__`.
  RulesPathValue get name => RulesPathValue([
    'databases',
    '(default)',
    'documents',
    ...path.split('/'),
  ]);

  @override
  String toString() => 'Resource($path, $data)';
}

/// The authenticated user of a request.
class FirestoreRulesAuth {
  /// The user id.
  final String uid;

  /// The id token claims (`email`, `email_verified`, custom claims...).
  final Map<String, Object?> token;

  /// Creates an auth context; `sub` and `user_id` are added to [token] when
  /// missing, like in a real id token.
  FirestoreRulesAuth({required this.uid, Map<String, Object?>? token})
    : token = {'sub': uid, 'user_id': uid, ...?token};

  @override
  String toString() => 'Auth($uid, $token)';
}

/// Reads documents for `get()` and `exists()` (and the existing document of
/// a write).
abstract class RulesDocumentReader {
  /// The document data at [path], null if it does not exist.
  Future<Map<String, Object?>?> read(String path);
}

/// A request to evaluate.
class RulesRequest {
  /// The concrete method (`get`, `list`, `create`, `update` or `delete`).
  final RulesMethod method;

  /// Document path for single document methods, collection path for `list`.
  final String path;

  /// The user, null when signed out.
  final FirestoreRulesAuth? auth;

  /// The existing document data, null when it does not exist (or for `list`).
  final Map<String, Object?>? resourceData;

  /// The document data after the write, null for reads.
  final Map<String, Object?>? requestResourceData;

  /// The request time.
  final Timestamp time;

  /// True for requests that are part of a batch or a transaction (the access
  /// call limit is then 20 instead of 10).
  final bool multi;

  /// Creates a request.
  RulesRequest({
    required this.method,
    required this.path,
    required this.auth,
    this.resourceData,
    this.requestResourceData,
    Timestamp? time,
    this.multi = false,
  }) : time = time ?? Timestamp.fromDateTime(DateTime.now());

  @override
  String toString() => '${method.name} $path ${auth?.uid ?? '<anonymous>'}';
}

/// The outcome of an evaluation.
class RulesDecision {
  /// Whether the request is allowed.
  final bool allowed;

  /// One line per evaluated allow statement, for debugging.
  final List<String> trace;

  /// Number of distinct documents accessed through `get()`/`exists()`.
  final int accessCalls;

  /// Creates a decision.
  RulesDecision({
    required this.allowed,
    required this.trace,
    required this.accessCalls,
  });

  @override
  String toString() =>
      '${allowed ? 'allowed' : 'denied'} ($accessCalls access calls)\n'
      '${trace.join('\n')}';
}

/// Evaluates [FirestoreRules] against requests, replicating the engine
/// semantics: matching (nested blocks, single and recursive wildcards, unbound
/// wildcards on `list`), any matching `allow` grants, evaluation errors deny,
/// `&&`/`||` short circuit, `get()` of a missing document is null, member
/// access on a missing key is an error, `get()`/`exists()` results are cached
/// per request and limited to 10 (20 for batches and transactions) distinct
/// documents.
class RulesEvaluator {
  /// The rules.
  final FirestoreRules rules;

  /// Max distinct documents accessed per single document request.
  final int accessCallLimit;

  /// Max distinct documents accessed per batch/transaction request.
  final int multiAccessCallLimit;

  late final Map<String, RulesFunction> _functions = rules.functionsByName;

  /// Creates an evaluator for [rules].
  RulesEvaluator(
    this.rules, {
    this.accessCallLimit = 10,
    this.multiAccessCallLimit = 20,
  });

  /// Evaluates [request], reading documents through [reader].
  Future<RulesDecision> evaluate(
    RulesRequest request,
    RulesDocumentReader reader,
  ) async {
    var context = _EvalContext(this, request, reader);
    var segments = request.path.split('/').where((s) => s.isNotEmpty).toList();
    var isList = request.method == RulesMethod.list;
    if (isList) {
      if (segments.length.isEven) {
        throw ArgumentError.value(
          request.path,
          'path',
          'A list request path must be a collection path',
        );
      }
    } else if (segments.length.isOdd || segments.isEmpty) {
      throw ArgumentError.value(
        request.path,
        'path',
        'A document request path must be a document path',
      );
    }
    var matchSegments = <Object>[
      ...segments,
      if (isList) RulesUnbound.instance,
    ];
    var matches = <_MatchedBlock>[];
    _collect(
      rules.documents,
      matchSegments,
      {'database': '(default)'},
      matches,
      root: true,
    );
    var allowed = false;
    for (var matched in matches) {
      for (var item in matched.match.items) {
        if (item is! RulesAllow || !item.appliesTo(request.method)) {
          continue;
        }
        var label =
            '${matched.match.pattern} allow ${item.methods.map((m) => m.name).join(', ')}';
        try {
          var value = await context.eval(item.condition, matched.bindings);
          if (value == true) {
            context.trace.add('$label: true');
            allowed = true;
          } else {
            context.trace.add('$label: $value');
          }
        } on RulesEvalError catch (e) {
          context.trace.add('$label: error ${e.message}');
        }
        if (allowed) {
          break;
        }
      }
      if (allowed) {
        break;
      }
    }
    return RulesDecision(
      allowed: allowed,
      trace: context.trace,
      accessCalls: context.accessed.length,
    );
  }

  void _collect(
    RulesMatch match,
    List<Object> segments,
    Map<String, Object?> bindings,
    List<_MatchedBlock> out, {
    bool root = false,
  }) {
    if (!root) {
      var result = _matchPattern(match.pattern, segments);
      if (result == null) {
        return;
      }
      bindings = {...bindings, ...result.bindings};
      segments = result.remaining;
    }
    if (segments.isEmpty) {
      out.add(_MatchedBlock(match, bindings));
    }
    for (var item in match.items) {
      if (item is RulesMatch) {
        _collect(item, segments, bindings, out);
      }
    }
  }

  /// Matches [pattern] at the start of [segments].
  _PatternResult? _matchPattern(
    RulesPathPattern pattern,
    List<Object> segments,
  ) {
    var bindings = <String, Object?>{};
    var index = 0;
    for (var patternSegment in pattern.segments) {
      if (patternSegment.isRecursive) {
        // Zero or more remaining segments.
        var rest = segments.sublist(index);
        if (rest.any((s) => s is RulesUnbound)) {
          bindings[patternSegment.text] = RulesUnbound.instance;
        } else {
          bindings[patternSegment.text] = rest.join('/');
        }
        return _PatternResult(bindings, const []);
      }
      if (index >= segments.length) {
        return null;
      }
      var segment = segments[index++];
      if (patternSegment.isWildcard) {
        bindings[patternSegment.text] = segment;
      } else if (segment != patternSegment.text) {
        return null;
      }
    }
    return _PatternResult(bindings, segments.sublist(index));
  }
}

class _PatternResult {
  final Map<String, Object?> bindings;
  final List<Object> remaining;

  _PatternResult(this.bindings, this.remaining);
}

class _MatchedBlock {
  final RulesMatch match;
  final Map<String, Object?> bindings;

  _MatchedBlock(this.match, this.bindings);
}

/// Sentinel for a variable declared but not bound (function param mismatch).
const _missing = Object();

class _EvalContext {
  final RulesEvaluator evaluator;
  final RulesRequest request;
  final RulesDocumentReader reader;
  final trace = <String>[];

  /// Documents accessed so far (cache and limit).
  final accessed = <String, RulesResourceValue?>{};

  _EvalContext(this.evaluator, this.request, this.reader);

  int get _limit => request.multi
      ? evaluator.multiAccessCallLimit
      : evaluator.accessCallLimit;

  late final Map<String, Object?> _globals = {
    'request': _requestValue(),
    'resource': request.resourceData == null
        ? null
        : RulesResourceValue(request.path, request.resourceData!),
  };

  Map<String, Object?> _requestValue() {
    var auth = request.auth;
    return {
      'auth': auth == null ? null : {'uid': auth.uid, 'token': auth.token},
      'resource': request.requestResourceData == null
          ? null
          : RulesResourceValue(request.path, request.requestResourceData!),
      'method': request.method.name,
      'path': RulesPathValue([
        'databases',
        '(default)',
        'documents',
        ...request.path.split('/'),
      ]),
      'time': request.time,
    };
  }

  Future<RulesResourceValue?> _access(Object? pathValue) async {
    if (pathValue is! RulesPathValue) {
      throw RulesEvalError('get()/exists() expects a path, got $pathValue');
    }
    var path = pathValue.documentPath;
    if (accessed.containsKey(path)) {
      return accessed[path];
    }
    if (accessed.length >= _limit) {
      throw RulesEvalError(
        'Too many document access calls (limit $_limit) accessing $path',
      );
    }
    var data = await reader.read(path);
    var value = data == null ? null : RulesResourceValue(path, data);
    accessed[path] = value;
    return value;
  }

  Future<Object?> eval(RulesExpr expr, Map<String, Object?> scope) async {
    switch (expr) {
      case RulesLiteral():
        return _evalLiteral(expr.value, scope);
      case RulesVar():
        return _lookup(expr.name, scope);
      case RulesMember():
        var target = await eval(expr.target, scope);
        return _member(target, expr.name);
      case RulesIndex():
        var target = await eval(expr.target, scope);
        var key = await eval(expr.key, scope);
        return _index(target, key);
      case RulesMethodCall():
        var target = await eval(expr.target, scope);
        var args = <Object?>[];
        for (var arg in expr.args) {
          args.add(await eval(arg, scope));
        }
        return _methodCall(target, expr.method, args);
      case RulesCall():
        return _call(expr, scope);
      case RulesBinary():
        return _binary(expr, scope);
      case RulesNot():
        var value = await eval(expr.expr, scope);
        if (value is bool) {
          return !value;
        }
        throw RulesEvalError('! expects a bool, got $value');
      case RulesIs():
        var value = await eval(expr.expr, scope);
        return _isType(value, expr.type);
      case RulesConditional():
        var condition = await eval(expr.condition, scope);
        if (condition is! bool) {
          throw RulesEvalError('condition must be a bool, got $condition');
        }
        return condition
            ? await eval(expr.ifTrue, scope)
            : await eval(expr.ifFalse, scope);
      case RulesPath():
        var segments = <String>[];
        for (var segment in expr.segments) {
          if (segment is RulesExpr) {
            var value = await eval(segment, scope);
            segments.add(_pathSegmentText(value));
          } else {
            segments.add(segment as String);
          }
        }
        return RulesPathValue(segments);
      default:
        throw RulesEvalError('Unsupported expression ${expr.runtimeType}');
    }
  }

  String _pathSegmentText(Object? value) {
    if (value is String) {
      return value;
    }
    if (value is RulesUnbound) {
      throw RulesEvalError('Unbound wildcard used in a path');
    }
    if (value == null) {
      throw RulesEvalError('Null value used in a path');
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    throw RulesEvalError('Cannot use ${value.runtimeType} in a path');
  }

  Future<Object?> _evalLiteral(
    Object? value,
    Map<String, Object?> scope,
  ) async {
    if (value is List) {
      var list = <Object?>[];
      for (var item in value) {
        list.add(await eval(rulesExpr(item), scope));
      }
      return list;
    }
    if (value is Map) {
      var map = <String, Object?>{};
      for (var entry in value.entries) {
        map[entry.key as String] = await eval(rulesExpr(entry.value), scope);
      }
      return map;
    }
    return value;
  }

  Object? _lookup(String name, Map<String, Object?> scope) {
    if (scope.containsKey(name)) {
      var value = scope[name];
      if (identical(value, _missing)) {
        throw RulesEvalError('Variable $name not bound');
      }
      return value;
    }
    if (_globals.containsKey(name)) {
      return _globals[name];
    }
    throw RulesEvalError('Unknown variable $name');
  }

  Object? _member(Object? target, String name) {
    _checkBound(target);
    if (target == null) {
      throw RulesEvalError('Null value error (.$name)');
    }
    if (target is RulesResourceValue) {
      switch (name) {
        case 'data':
          return target.data;
        case 'id':
          return target.id;
        case '__name__':
          return target.name;
      }
      throw RulesEvalError('Unknown resource member $name');
    }
    if (target is Map) {
      if (target.containsKey(name)) {
        return _normalize(target[name]);
      }
      throw RulesEvalError('Property $name is undefined on object');
    }
    throw RulesEvalError('Cannot access .$name on ${target.runtimeType}');
  }

  Object? _index(Object? target, Object? key) {
    _checkBound(target);
    _checkBound(key);
    if (target is Map) {
      if (target.containsKey(key)) {
        return _normalize(target[key]);
      }
      throw RulesEvalError('Key $key is undefined on map');
    }
    if (target is List) {
      if (key is int && key >= 0 && key < target.length) {
        return _normalize(target[key]);
      }
      throw RulesEvalError('Index $key out of range');
    }
    if (target is String) {
      if (key is int && key >= 0 && key < target.length) {
        return target[key];
      }
      throw RulesEvalError('Index $key out of range');
    }
    if (target is RulesPathValue) {
      if (key is int && key >= 0 && key < target.segments.length) {
        return target.segments[key];
      }
      throw RulesEvalError('Index $key out of range');
    }
    throw RulesEvalError('Cannot index ${target.runtimeType}');
  }

  /// Converts backend values to rules values.
  Object? _normalize(Object? value) {
    if (value is DocumentReference) {
      return RulesPathValue([
        'databases',
        '(default)',
        'documents',
        ...value.path.split('/'),
      ]);
    }
    if (value is DateTime) {
      return Timestamp.fromDateTime(value);
    }
    return value;
  }

  void _checkBound(Object? value) {
    if (value is RulesUnbound) {
      throw RulesEvalError('Unbound wildcard used in an expression');
    }
  }

  Object? _methodCall(Object? target, String method, List<Object?> args) {
    _checkBound(target);
    args.forEach(_checkBound);
    if (target == null) {
      throw RulesEvalError('Null value error (.$method())');
    }
    if (target is RulesResourceValue && method == 'data') {
      return target.data;
    }
    if (target is Map) {
      switch (method) {
        case 'get':
          if (args.length != 2) {
            throw RulesEvalError('get(key, default) expects 2 arguments');
          }
          var key = args[0];
          if (key is List) {
            // Nested path lookup.
            Object? current = target;
            for (var part in key) {
              if (current is Map && current.containsKey(part)) {
                current = current[part];
              } else {
                return args[1];
              }
            }
            return _normalize(current);
          }
          return target.containsKey(key) ? _normalize(target[key]) : args[1];
        case 'keys':
          return target.keys.toList();
        case 'values':
          return target.values.map(_normalize).toList();
        case 'size':
          return target.length;
      }
      throw RulesEvalError('Unknown map method $method');
    }
    if (target is List) {
      switch (method) {
        case 'size':
          return target.length;
        case 'hasAny':
          return _asList(args.single).any(target.contains);
        case 'hasAll':
          return _asList(args.single).every(target.contains);
        case 'hasOnly':
          var allowed = _asList(args.single);
          return target.every(allowed.contains);
        case 'join':
          return target.join(args.single as String);
        case 'concat':
          return [...target, ..._asList(args.single)];
        case 'removeAll':
          var removed = _asList(args.single);
          return target.where((item) => !removed.contains(item)).toList();
        case 'toSet':
          return target.toSet().toList();
      }
      throw RulesEvalError('Unknown list method $method');
    }
    if (target is String) {
      switch (method) {
        case 'lower':
          return target.toLowerCase();
        case 'upper':
          return target.toUpperCase();
        case 'size':
          return target.length;
        case 'trim':
          return target.trim();
        case 'matches':
          return RegExp('^(?:${args.single as String})\$').hasMatch(target);
        case 'split':
          return target.split(RegExp(args.single as String));
        case 'replace':
          return target.replaceAll(
            RegExp(args[0] as String),
            args[1] as String,
          );
        case 'toUtf8':
          return target;
      }
      throw RulesEvalError('Unknown string method $method');
    }
    if (target is Timestamp) {
      switch (method) {
        case 'toMillis':
          return target.seconds * 1000 + target.nanoseconds ~/ 1000000;
        case 'seconds':
          return target.seconds;
        case 'nanos':
          return target.nanoseconds;
        case 'year':
          return target.toDateTime().year;
        case 'month':
          return target.toDateTime().month;
        case 'day':
          return target.toDateTime().day;
      }
      throw RulesEvalError('Unknown timestamp method $method');
    }
    if (target is RulesPathValue) {
      switch (method) {
        case 'size':
          return target.segments.length;
        case 'bind':
          return target;
      }
      throw RulesEvalError('Unknown path method $method');
    }
    throw RulesEvalError('Cannot call .$method() on ${target.runtimeType}');
  }

  List _asList(Object? value) {
    if (value is List) {
      return value;
    }
    throw RulesEvalError('Expected a list, got $value');
  }

  Future<Object?> _call(RulesCall call, Map<String, Object?> scope) async {
    var args = <Object?>[];
    for (var arg in call.args) {
      args.add(await eval(arg, scope));
    }
    switch (call.name) {
      case 'get':
        return _access(args.single);
      case 'exists':
        return (await _access(args.single)) != null;
      case 'getAfter':
      case 'existsAfter':
        throw RulesEvalError(
          '${call.name}() is not supported by the simulator',
        );
      case 'debug':
        return args.single;
      case 'path':
        var text = args.single;
        if (text is String) {
          return RulesPathValue(
            text.split('/').where((s) => s.isNotEmpty).toList(),
          );
        }
        throw RulesEvalError('path() expects a string');
      case 'timestamp':
      case 'duration':
        throw RulesEvalError('${call.name} namespace not supported');
    }
    var function = evaluator._functions[call.name];
    if (function == null) {
      throw RulesEvalError('Unknown function ${call.name}');
    }
    if (function.params.length != args.length) {
      throw RulesEvalError(
        'Function ${call.name} expects ${function.params.length} arguments',
      );
    }
    // Functions only see their parameters and lets, plus the wildcards of the
    // enclosing matches (kept from the caller scope, the real engine does the
    // same for functions declared inside a match).
    var functionScope = <String, Object?>{...scope};
    for (var i = 0; i < args.length; i++) {
      functionScope[function.params[i]] = args[i];
    }
    for (var let in function.lets) {
      functionScope[let.name] = await eval(let.expr, functionScope);
    }
    return eval(function.body, functionScope);
  }

  Future<Object?> _binary(RulesBinary expr, Map<String, Object?> scope) async {
    var op = expr.op;
    if (op == '&&' || op == '||') {
      return _logical(expr, scope);
    }
    var left = await eval(expr.left, scope);
    var right = await eval(expr.right, scope);
    _checkBound(left);
    _checkBound(right);
    switch (op) {
      case '==':
        return _equals(left, right);
      case '!=':
        return !_equals(left, right);
      case 'in':
        if (right is List) {
          return right.any((item) => _equals(item, left));
        }
        if (right is Map) {
          return right.containsKey(left);
        }
        throw RulesEvalError('in expects a list or a map, got $right');
      case '<':
        return _compare(left, right) < 0;
      case '<=':
        return _compare(left, right) <= 0;
      case '>':
        return _compare(left, right) > 0;
      case '>=':
        return _compare(left, right) >= 0;
      case '+':
        if (left is String && right is String) {
          return left + right;
        }
        if (left is num && right is num) {
          return left + right;
        }
        if (left is List && right is List) {
          return [...left, ...right];
        }
        throw RulesEvalError('Cannot add $left and $right');
      case '-':
        if (left is num && right is num) {
          return left - right;
        }
        throw RulesEvalError('Cannot subtract $left and $right');
      case '*':
        if (left is num && right is num) {
          return left * right;
        }
        throw RulesEvalError('Cannot multiply $left and $right');
      case '/':
        if (left is num && right is num) {
          if (right == 0) {
            throw RulesEvalError('Division by zero');
          }
          return left is int && right is int ? left ~/ right : left / right;
        }
        throw RulesEvalError('Cannot divide $left and $right');
      case '%':
        if (left is int && right is int) {
          if (right == 0) {
            throw RulesEvalError('Division by zero');
          }
          return left % right;
        }
        throw RulesEvalError('Cannot modulo $left and $right');
    }
    throw RulesEvalError('Unknown operator $op');
  }

  /// `&&`/`||` with short circuit and error absorption: an error on one side
  /// is absorbed when the other side decides the result.
  Future<Object?> _logical(RulesBinary expr, Map<String, Object?> scope) async {
    var isAnd = expr.op == '&&';
    RulesEvalError? leftError;
    Object? left;
    try {
      left = await eval(expr.left, scope);
      if (left is! bool) {
        throw RulesEvalError('${expr.op} expects bools, got $left');
      }
      if (left == !isAnd) {
        // false && ..., true || ...
        return left;
      }
    } on RulesEvalError catch (e) {
      leftError = e;
    }
    var right = await eval(expr.right, scope);
    if (right is! bool) {
      throw RulesEvalError('${expr.op} expects bools, got $right');
    }
    if (leftError != null) {
      if (right == !isAnd) {
        return right;
      }
      throw leftError;
    }
    return right;
  }

  bool _equals(Object? left, Object? right) {
    if (left is num && right is num) {
      return left == right;
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var i = 0; i < left.length; i++) {
        if (!_equals(left[i], right[i])) {
          return false;
        }
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (var key in left.keys) {
        if (!right.containsKey(key) || !_equals(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is Timestamp && right is Timestamp) {
      return left.compareTo(right) == 0;
    }
    return left == right;
  }

  int _compare(Object? left, Object? right) {
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is String && right is String) {
      return left.compareTo(right);
    }
    if (left is Timestamp && right is Timestamp) {
      return left.compareTo(right);
    }
    throw RulesEvalError('Cannot compare $left and $right');
  }

  bool _isType(Object? value, String type) {
    _checkBound(value);
    switch (type) {
      case 'string':
        return value is String;
      case 'int':
        return value is int;
      case 'float':
        return value is double;
      case 'number':
        return value is num;
      case 'bool':
        return value is bool;
      case 'list':
        return value is List;
      case 'map':
        return value is Map;
      case 'timestamp':
        return value is Timestamp;
      case 'path':
        return value is RulesPathValue;
      case 'null':
        return value == null;
      case 'bytes':
        return value is Blob;
      case 'latlng':
        return value is GeoPoint;
    }
    throw RulesEvalError('Unknown type $type');
  }
}
