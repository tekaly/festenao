import 'rules_expression.dart';
import 'rules_writer.dart';

/// The access methods of the rules language.
enum RulesMethod {
  /// `read`: `get` and `list`.
  read,

  /// `write`: `create`, `update` and `delete`.
  write,

  /// Single document read.
  get,

  /// Query / collection read.
  list,

  /// Document creation.
  create,

  /// Existing document update.
  update,

  /// Document deletion.
  delete;

  /// The concrete methods this method stands for (`read` and `write` expand,
  /// the others return themselves).
  List<RulesMethod> get expanded {
    switch (this) {
      case RulesMethod.read:
        return [RulesMethod.get, RulesMethod.list];
      case RulesMethod.write:
        return [RulesMethod.create, RulesMethod.update, RulesMethod.delete];
      default:
        return [this];
    }
  }

  /// True if this (possibly composite) method covers [method].
  bool covers(RulesMethod method) => expanded.contains(method);
}

/// An item of a match block or of the root: a comment, a blank line, a
/// function, an allow statement or a nested match.
abstract class RulesNode {
  /// Const constructor.
  const RulesNode();
}

/// A `//` comment (one line per line of [text]).
class RulesComment extends RulesNode {
  /// The comment text, possibly multi-line, without the `//`.
  final String text;

  /// Creates a comment.
  const RulesComment(this.text);
}

/// An empty line, for readability of the generated file.
class RulesBlankLine extends RulesNode {
  /// Creates a blank line.
  const RulesBlankLine();
}

/// A named `let` binding inside a function body.
class RulesLet {
  /// The binding name.
  final String name;

  /// The bound expression.
  final RulesExpr expr;

  /// Creates a let binding.
  const RulesLet(this.name, this.expr);
}

/// A rules function declaration.
class RulesFunction extends RulesNode {
  /// The function name.
  final String name;

  /// The parameter names.
  final List<String> params;

  /// The `let` bindings, in declaration order.
  final List<RulesLet> lets;

  /// The returned expression.
  final RulesExpr body;

  /// Creates a function declaration.
  const RulesFunction({
    required this.name,
    required this.params,
    required this.lets,
    required this.body,
  });

  /// A call to this function with [args].
  RulesExpr call(List<Object?> args) {
    if (args.length != params.length) {
      throw ArgumentError(
        'Function $name expects ${params.length} arguments, got ${args.length}',
      );
    }
    return rulesCall(name, args);
  }
}

/// The scope handed to a function body builder: its parameters and `let`
/// bindings.
class RulesFunctionScope {
  /// The function name.
  final String name;

  /// The parameters, in order.
  final List<RulesVar> params;
  final _lets = <RulesLet>[];

  /// Creates a scope for the function [name] with [paramNames].
  RulesFunctionScope(this.name, List<String> paramNames)
    : params = paramNames.map(RulesVar.new).toList();

  /// The parameter named [name] (throws if it does not exist).
  RulesVar param(String name) => params.firstWhere(
    (param) => param.name == name,
    orElse: () => throw ArgumentError('Unknown param $name in ${this.name}'),
  );

  /// The parameter at [index].
  RulesVar operator [](int index) => params[index];

  /// Declares `let name = expr;` and returns the variable.
  RulesVar let(String name, Object? expr) {
    _lets.add(RulesLet(name, rulesExpr(expr)));
    return RulesVar(name);
  }
}

/// An `allow methods: if condition;` statement.
class RulesAllow extends RulesNode {
  /// The methods.
  final List<RulesMethod> methods;

  /// The condition.
  final RulesExpr condition;

  /// Creates an allow statement.
  const RulesAllow(this.methods, this.condition);

  /// True if this statement applies to the concrete [method].
  bool appliesTo(RulesMethod method) =>
      methods.any((allowed) => allowed.covers(method));
}

/// One segment of a match pattern.
class RulesPatternSegment {
  /// Literal text, or the wildcard name.
  final String text;

  /// True for `{name}` and `{name=**}`.
  final bool isWildcard;

  /// True for `{name=**}`.
  final bool isRecursive;

  /// Creates a segment.
  const RulesPatternSegment(
    this.text, {
    this.isWildcard = false,
    this.isRecursive = false,
  });

  /// Parses `literal`, `{name}` or `{name=**}`.
  factory RulesPatternSegment.parse(String segment) {
    if (segment.startsWith('{') && segment.endsWith('}')) {
      var inner = segment.substring(1, segment.length - 1);
      if (inner.endsWith('=**')) {
        return RulesPatternSegment(
          inner.substring(0, inner.length - 3),
          isWildcard: true,
          isRecursive: true,
        );
      }
      return RulesPatternSegment(inner, isWildcard: true);
    }
    return RulesPatternSegment(segment);
  }

  @override
  String toString() =>
      isWildcard ? (isRecursive ? '{$text=**}' : '{$text}') : text;
}

/// A match path pattern such as `/{top}/{topId}/access/{document=**}`.
class RulesPathPattern {
  /// The segments.
  final List<RulesPatternSegment> segments;

  /// Creates a pattern from segments.
  const RulesPathPattern(this.segments);

  /// Parses a pattern text, the leading `/` is optional.
  factory RulesPathPattern.parse(String pattern) {
    var parts = pattern.split('/').where((part) => part.isNotEmpty);
    var segments = parts.map(RulesPatternSegment.parse).toList();
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i].isRecursive) {
        throw ArgumentError.value(
          pattern,
          'pattern',
          'A recursive wildcard must be the last segment',
        );
      }
    }
    return RulesPathPattern(segments);
  }

  /// The wildcard names.
  List<String> get wildcardNames => segments
      .where((segment) => segment.isWildcard)
      .map((segment) => segment.text)
      .toList();

  @override
  String toString() => '/${segments.join('/')}';
}

/// A `match /pattern { ... }` block.
///
/// Built imperatively: [comment], [function], [allow] and [match] append to
/// the block in call order, which is also the order of the generated text.
class RulesMatch extends RulesNode {
  /// The parent block, null for the root.
  final RulesMatch? parent;

  /// The path pattern, relative to [parent].
  final RulesPathPattern pattern;

  /// The items, in order.
  final List<RulesNode> items = [];

  /// Creates a match block under [parent].
  RulesMatch(String pattern, {this.parent})
    : pattern = RulesPathPattern.parse(pattern);

  /// The wildcard names bound by this block and its ancestors.
  List<String> get boundWildcardNames => [
    ...?parent?.boundWildcardNames,
    ...pattern.wildcardNames,
  ];

  /// The variable of the wildcard [name], bound by this block or one of its
  /// ancestors (throws otherwise, catching typos early).
  RulesVar v(String name) {
    if (!boundWildcardNames.contains(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Wildcard not bound in $pattern (bound: $boundWildcardNames)',
      );
    }
    return RulesVar(name);
  }

  /// The variables of the wildcards of this block only, in order.
  List<RulesVar> get vars => pattern.wildcardNames.map(RulesVar.new).toList();

  /// Adds a comment.
  void comment(String text) => items.add(RulesComment(text));

  /// Adds a blank line.
  void blankLine() => items.add(const RulesBlankLine());

  /// Adds `allow methods: if condition;`.
  ///
  /// [condition] is a [RulesExpr] or a `bool`.
  RulesAllow allow(List<RulesMethod> methods, Object condition) {
    var node = RulesAllow(methods, rulesExpr(condition));
    items.add(node);
    return node;
  }

  /// Adds a nested match block; [build] receives it to fill it in.
  RulesMatch match(String pattern, [void Function(RulesMatch match)? build]) {
    var node = RulesMatch(pattern, parent: this);
    // Built before being added: functions declared while building (in the
    // root block) end up before the match that uses them.
    build?.call(node);
    items.add(node);
    return node;
  }

  /// Declares a function.
  ///
  /// [body] receives the function scope (its parameters, and `let` through
  /// [RulesFunctionScope.let]) and returns the returned expression.
  RulesFunction function(
    String name,
    List<String> params,
    Object? Function(RulesFunctionScope f) body,
  ) {
    var scope = RulesFunctionScope(name, params);
    var expr = rulesExpr(body(scope));
    var node = RulesFunction(
      name: name,
      params: params,
      lets: List.unmodifiable(scope._lets),
      body: expr,
    );
    items.add(node);
    return node;
  }

  /// Adds the function [node] declared elsewhere (used to share a function
  /// declaration object between rule sets).
  void addFunction(RulesFunction node) => items.add(node);

  /// All the functions declared in this block and below.
  Iterable<RulesFunction> get allFunctions sync* {
    for (var item in items) {
      if (item is RulesFunction) {
        yield item;
      } else if (item is RulesMatch) {
        yield* item.allFunctions;
      }
    }
  }
}

/// A firestore rules file, built imperatively.
///
/// ```dart
/// var rules = FirestoreRules();
/// var signedIn = rules.function('signedIn', [], (f) =>
///     request.auth.isNotNull & request.auth.uid.isNotNull);
/// rules.match('/user/{userId}', (m) {
///   m.allow([RulesMethod.read, RulesMethod.write],
///       signedIn.call([]) & request.auth.uid.eq(m.v('userId')));
/// });
/// print(rules.toRulesText());
/// ```
class FirestoreRules {
  /// The `rules_version`, `'2'` by default.
  final String rulesVersion;

  /// Comments written after the version line, before the service block.
  final List<String> headerComments = [];

  /// The `/databases/{database}/documents` block every rule lives in.
  final RulesMatch documents = RulesMatch('/databases/{database}/documents');

  /// Creates an empty rules file.
  FirestoreRules({this.rulesVersion = '2'});

  /// Adds a header comment (multi-line allowed).
  void headerComment(String text) => headerComments.add(text);

  /// Adds a comment to the documents block.
  void comment(String text) => documents.comment(text);

  /// Adds a blank line to the documents block.
  void blankLine() => documents.blankLine();

  /// Adds a match block to the documents block.
  RulesMatch match(String pattern, [void Function(RulesMatch match)? build]) =>
      documents.match(pattern, build);

  /// Declares a function in the documents block.
  RulesFunction function(
    String name,
    List<String> params,
    Object? Function(RulesFunctionScope f) body,
  ) => documents.function(name, params, body);

  /// Adds the `match /{document=**} { allow read, write: if false; }` block
  /// (explicit default, everything is denied anyway).
  void denyAll() {
    match('/{document=**}', (m) {
      m.allow([RulesMethod.read, RulesMethod.write], false);
    });
  }

  /// All the declared functions, by name (duplicates throw).
  Map<String, RulesFunction> get functionsByName {
    var map = <String, RulesFunction>{};
    for (var function in documents.allFunctions) {
      if (map.containsKey(function.name)) {
        throw StateError('Function ${function.name} declared twice');
      }
      map[function.name] = function;
    }
    return map;
  }

  /// The rules file text.
  String toRulesText() => rulesToText(this);

  @override
  String toString() => toRulesText();
}
