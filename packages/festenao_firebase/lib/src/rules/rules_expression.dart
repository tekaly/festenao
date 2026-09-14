import 'package:meta/meta.dart';

/// Converts a Dart value into a rules expression.
///
/// [value] is returned as is when it already is a [RulesExpr]; a `String`,
/// `num`, `bool`, `null`, `List` or `Map` becomes a [RulesLiteral] (list and
/// map items are converted recursively). Any other type throws an
/// [ArgumentError].
RulesExpr rulesExpr(Object? value) {
  if (value is RulesExpr) {
    return value;
  }
  if (value == null || value is String || value is num || value is bool) {
    return RulesLiteral(value);
  }
  if (value is List) {
    return RulesLiteral(value.map(rulesExpr).toList());
  }
  if (value is Map) {
    return RulesLiteral(
      value.map((key, value) => MapEntry(key as String, rulesExpr(value))),
    );
  }
  throw ArgumentError.value(value, 'value', 'Cannot convert to a rules expr');
}

/// Shortcut for [rulesExpr], typically used to wrap a literal: `lit('admin')`.
RulesExpr lit(Object? value) => rulesExpr(value);

/// The `request` variable of the rules language.
const RulesExpr request = RulesVar('request');

/// The `resource` variable of the rules language (the existing document).
const RulesExpr resource = RulesVar('resource');

/// `request.auth`.
final RulesExpr requestAuth = request.auth;

/// `request.auth.uid`.
final RulesExpr requestAuthUid = request.auth.uid;

/// `request.auth.token`.
final RulesExpr requestAuthToken = request.auth.token;

/// `request.resource` (the document as it would be after the write).
final RulesExpr requestResource = request.resource;

/// `request.resource.data`.
final RulesExpr requestResourceData = request.resource.data;

/// `resource.data`.
final RulesExpr resourceData = resource.data;

/// `request.time`.
final RulesExpr requestTime = request.member('time');

/// `request.method`.
final RulesExpr requestMethod = request.member('method');

/// `request.path`.
final RulesExpr requestPath = request.member('path');

/// The `database` wildcard bound by the `/databases/{database}/documents`
/// match every rules file starts with.
const RulesExpr database = RulesVar('database');

/// `get(path)`: the document at [path], or `null` when it does not exist.
///
/// [path] is usually built with [docPath].
RulesExpr rulesGet(Object path) => RulesCall('get', [rulesExpr(path)]);

/// `exists(path)`: whether the document at [path] exists.
RulesExpr rulesExists(Object path) => RulesCall('exists', [rulesExpr(path)]);

/// `getAfter(path)`: the document at [path] as it would be after the current
/// write (not supported by the simulator, kept for text generation).
RulesExpr rulesGetAfter(Object path) =>
    RulesCall('getAfter', [rulesExpr(path)]);

/// A full document path expression:
/// `/databases/$(database)/documents/<segments>`.
///
/// Each item of [segments] is a literal `String` (written as is, a string with
/// `/` is split), or a [RulesExpr] (written interpolated as `$(expr)`).
RulesPath docPath(List<Object> segments) {
  var all = <Object>[];
  for (var segment in segments) {
    if (segment is String) {
      all.addAll(segment.split('/').where((part) => part.isNotEmpty));
    } else {
      all.add(rulesExpr(segment));
    }
  }
  return RulesPath(['databases', database, 'documents', ...all]);
}

/// Calls a rules function declared with `function(...)` by [name].
RulesExpr rulesCall(String name, [List<Object?> args = const []]) =>
    RulesCall(name, args.map(rulesExpr).toList());

/// Base class of every expression of the rules language.
///
/// Expressions are built through the operators and helpers below (`&`, `|`,
/// `~`, [eq], [member], [get]...), can be written as text (see
/// `FirestoreRules.toRulesText()`) and evaluated by the simulator.
@immutable
abstract class RulesExpr {
  /// Const constructor for subclasses.
  const RulesExpr();

  /// Precedence used by the writer to decide where parentheses are needed
  /// (higher binds tighter).
  int get precedence => 100;

  /// `this && other`.
  RulesExpr operator &(Object other) =>
      RulesBinary('&&', this, rulesExpr(other));

  /// `this || other`.
  RulesExpr operator |(Object other) =>
      RulesBinary('||', this, rulesExpr(other));

  /// `!this`.
  RulesExpr operator ~() => RulesNot(this);

  /// `this + other` (string concatenation or number addition).
  RulesExpr operator +(Object other) =>
      RulesBinary('+', this, rulesExpr(other));

  /// `this - other`.
  RulesExpr operator -(Object other) =>
      RulesBinary('-', this, rulesExpr(other));

  /// `this && other`, same as `&`.
  RulesExpr and(Object other) => this & other;

  /// `this || other`, same as `|`.
  RulesExpr or(Object other) => this | other;

  /// `!this`, same as `~`.
  RulesExpr not() => ~this;

  /// `this == other`.
  RulesExpr eq(Object? other) => RulesBinary('==', this, rulesExpr(other));

  /// `this != other`.
  RulesExpr neq(Object? other) => RulesBinary('!=', this, rulesExpr(other));

  /// `this < other`.
  RulesExpr lt(Object? other) => RulesBinary('<', this, rulesExpr(other));

  /// `this <= other`.
  RulesExpr lte(Object? other) => RulesBinary('<=', this, rulesExpr(other));

  /// `this > other`.
  RulesExpr gt(Object? other) => RulesBinary('>', this, rulesExpr(other));

  /// `this >= other`.
  RulesExpr gte(Object? other) => RulesBinary('>=', this, rulesExpr(other));

  /// `this in other` (list membership or map key presence).
  RulesExpr isIn(Object other) => RulesBinary('in', this, rulesExpr(other));

  /// `this is type` where [type] is `string`, `int`, `float`, `number`,
  /// `bool`, `list`, `map`, `timestamp`, `path`, `null`, `latlng`,
  /// `duration` or `bytes`.
  RulesExpr isType(String type) => RulesIs(this, type);

  /// `this == null`.
  RulesExpr get isNull => eq(null);

  /// `this != null`.
  RulesExpr get isNotNull => neq(null);

  /// `this.name`.
  RulesExpr member(String name) => RulesMember(this, name);

  /// `this[key]`.
  RulesExpr index(Object key) => RulesIndex(this, rulesExpr(key));

  /// `this.method(args)`.
  RulesExpr call(String method, [List<Object?> args = const []]) =>
      RulesMethodCall(this, method, args.map(rulesExpr).toList());

  /// `this.get(key, defaultValue)` (map lookup with a default).
  RulesExpr get(Object key, [Object? defaultValue]) =>
      call('get', [key, defaultValue]);

  /// `this ? ifTrue : ifFalse`.
  RulesExpr ternary(Object? ifTrue, Object? ifFalse) =>
      RulesConditional(this, rulesExpr(ifTrue), rulesExpr(ifFalse));

  /// `this.auth`.
  RulesExpr get auth => member('auth');

  /// `this.uid`.
  RulesExpr get uid => member('uid');

  /// `this.token`.
  RulesExpr get token => member('token');

  /// `this.resource`.
  RulesExpr get resource => member('resource');

  /// `this.data`.
  RulesExpr get data => member('data');

  /// `this.id`.
  RulesExpr get id => member('id');

  /// `this.email`.
  RulesExpr get email => member('email');

  /// `this.lower()`.
  RulesExpr lower() => call('lower');

  /// `this.upper()`.
  RulesExpr upper() => call('upper');

  /// `this.size()`.
  RulesExpr size() => call('size');

  /// `this.keys()`.
  RulesExpr keys() => call('keys');

  /// `this.hasAny(list)`.
  RulesExpr hasAny(Object list) => call('hasAny', [list]);

  /// `this.hasAll(list)`.
  RulesExpr hasAll(Object list) => call('hasAll', [list]);

  /// `this.hasOnly(list)`.
  RulesExpr hasOnly(Object list) => call('hasOnly', [list]);

  /// `this.matches(regExp)`.
  RulesExpr matches(Object regExp) => call('matches', [regExp]);

  /// The rules language text of this expression.
  String toRulesText() => rulesExprToText(this);

  @override
  String toString() => toRulesText();
}

/// A literal: `null`, `bool`, `num`, `String`, `List<RulesExpr>` or
/// `Map<String, RulesExpr>`.
class RulesLiteral extends RulesExpr {
  /// The literal value.
  final Object? value;

  /// Creates a literal, use [rulesExpr] to convert nested lists and maps.
  const RulesLiteral(this.value);
}

/// A variable reference: a match wildcard, a function parameter, a `let`
/// binding or one of the globals (`request`, `resource`).
class RulesVar extends RulesExpr {
  /// The variable name.
  final String name;

  /// Creates a variable reference.
  const RulesVar(this.name);
}

/// `target.name`.
class RulesMember extends RulesExpr {
  /// The object.
  final RulesExpr target;

  /// The member name.
  final String name;

  /// Creates a member access.
  const RulesMember(this.target, this.name);
}

/// `target[key]`.
class RulesIndex extends RulesExpr {
  /// The list or map.
  final RulesExpr target;

  /// The index or key.
  final RulesExpr key;

  /// Creates an index access.
  const RulesIndex(this.target, this.key);
}

/// `target.method(args)`.
class RulesMethodCall extends RulesExpr {
  /// The receiver.
  final RulesExpr target;

  /// The method name.
  final String method;

  /// The arguments.
  final List<RulesExpr> args;

  /// Creates a method call.
  const RulesMethodCall(this.target, this.method, this.args);
}

/// `name(args)`: a built-in (`get`, `exists`) or a user function call.
class RulesCall extends RulesExpr {
  /// The function name.
  final String name;

  /// The arguments.
  final List<RulesExpr> args;

  /// Creates a function call.
  const RulesCall(this.name, this.args);
}

/// `left op right`.
class RulesBinary extends RulesExpr {
  /// The operator: `&&`, `||`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `in`, `+`,
  /// `-`, `*`, `/`, `%`.
  final String op;

  /// Left operand.
  final RulesExpr left;

  /// Right operand.
  final RulesExpr right;

  /// Creates a binary expression.
  const RulesBinary(this.op, this.left, this.right);

  @override
  int get precedence => rulesBinaryPrecedence(op);
}

/// Precedence of a binary operator (higher binds tighter).
int rulesBinaryPrecedence(String op) {
  switch (op) {
    case '||':
      return 10;
    case '&&':
      return 20;
    case '==':
    case '!=':
      return 30;
    case '<':
    case '<=':
    case '>':
    case '>=':
    case 'in':
    case 'is':
      return 40;
    case '+':
    case '-':
      return 50;
    case '*':
    case '/':
    case '%':
      return 60;
    default:
      throw ArgumentError.value(op, 'op', 'Unknown binary operator');
  }
}

/// `!expr`.
class RulesNot extends RulesExpr {
  /// The negated expression.
  final RulesExpr expr;

  /// Creates a negation.
  const RulesNot(this.expr);

  @override
  int get precedence => 70;
}

/// `expr is type`.
class RulesIs extends RulesExpr {
  /// The tested expression.
  final RulesExpr expr;

  /// The type name.
  final String type;

  /// Creates a type test.
  const RulesIs(this.expr, this.type);

  @override
  int get precedence => 40;
}

/// `condition ? ifTrue : ifFalse`.
class RulesConditional extends RulesExpr {
  /// The condition.
  final RulesExpr condition;

  /// Value when true.
  final RulesExpr ifTrue;

  /// Value when false.
  final RulesExpr ifFalse;

  /// Creates a conditional expression.
  const RulesConditional(this.condition, this.ifTrue, this.ifFalse);

  @override
  int get precedence => 5;
}

/// A path literal `/seg/$(expr)/seg...`, see [docPath].
class RulesPath extends RulesExpr {
  /// The segments: `String` literals or interpolated [RulesExpr].
  final List<Object> segments;

  /// Creates a path from [segments].
  const RulesPath(this.segments);
}

/// Writes [expr] in the rules language.
String rulesExprToText(RulesExpr expr) {
  var sb = StringBuffer();
  _RulesExprWriter(sb).write(expr);
  return sb.toString();
}

/// Quotes [text] as a rules string literal.
String rulesStringLiteral(String text) {
  var escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}

class _RulesExprWriter {
  final StringBuffer sb;

  _RulesExprWriter(this.sb);

  void write(RulesExpr expr) {
    switch (expr) {
      case RulesLiteral():
        _writeLiteral(expr.value);
      case RulesVar():
        sb.write(expr.name);
      case RulesMember():
        _writeTarget(expr.target);
        sb.write('.${expr.name}');
      case RulesIndex():
        _writeTarget(expr.target);
        sb.write('[');
        write(expr.key);
        sb.write(']');
      case RulesMethodCall():
        _writeTarget(expr.target);
        sb.write('.${expr.method}(');
        _writeArgs(expr.args);
        sb.write(')');
      case RulesCall():
        sb.write('${expr.name}(');
        _writeArgs(expr.args);
        sb.write(')');
      case RulesBinary():
        _writeChild(expr.left, expr.precedence, rightSide: false, op: expr.op);
        sb.write(' ${expr.op} ');
        _writeChild(expr.right, expr.precedence, rightSide: true, op: expr.op);
      case RulesNot():
        sb.write('!');
        _writeChild(expr.expr, expr.precedence, rightSide: true, op: '!');
      case RulesIs():
        _writeChild(expr.expr, expr.precedence, rightSide: false, op: 'is');
        sb.write(' is ${expr.type}');
      case RulesConditional():
        _writeChild(
          expr.condition,
          expr.precedence + 1,
          rightSide: false,
          op: '?',
        );
        sb.write(' ? ');
        _writeChild(expr.ifTrue, expr.precedence + 1, rightSide: true, op: '?');
        sb.write(' : ');
        _writeChild(expr.ifFalse, expr.precedence, rightSide: true, op: '?');
      case RulesPath():
        for (var segment in expr.segments) {
          sb.write('/');
          if (segment is RulesExpr) {
            sb.write(r'$(');
            write(segment);
            sb.write(')');
          } else {
            sb.write(segment);
          }
        }
      default:
        throw UnsupportedError('Unsupported expression ${expr.runtimeType}');
    }
  }

  /// Member access targets: anything below member precedence gets parens.
  void _writeTarget(RulesExpr target) {
    if (target.precedence < 100) {
      sb.write('(');
      write(target);
      sb.write(')');
    } else {
      write(target);
    }
  }

  void _writeChild(
    RulesExpr child,
    int parentPrecedence, {
    required bool rightSide,
    required String op,
  }) {
    var needsParens = child.precedence < parentPrecedence;
    if (!needsParens && child.precedence == parentPrecedence && rightSide) {
      // Associative boolean operators chain without parentheses, anything
      // else on the right side is explicitly grouped.
      if (child is RulesBinary &&
          child.op == op &&
          (op == '&&' || op == '||')) {
        needsParens = false;
      } else {
        needsParens = true;
      }
    }
    if (needsParens) {
      sb.write('(');
      write(child);
      sb.write(')');
    } else {
      write(child);
    }
  }

  void _writeArgs(List<RulesExpr> args) {
    var first = true;
    for (var arg in args) {
      if (!first) {
        sb.write(', ');
      }
      first = false;
      write(arg);
    }
  }

  void _writeLiteral(Object? value) {
    if (value == null) {
      sb.write('null');
    } else if (value is String) {
      sb.write(rulesStringLiteral(value));
    } else if (value is bool || value is num) {
      sb.write(value);
    } else if (value is List) {
      sb.write('[');
      var first = true;
      for (var item in value) {
        if (!first) {
          sb.write(', ');
        }
        first = false;
        write(rulesExpr(item));
      }
      sb.write(']');
    } else if (value is Map) {
      sb.write('{');
      var first = true;
      for (var entry in value.entries) {
        if (!first) {
          sb.write(', ');
        }
        first = false;
        sb.write(rulesStringLiteral(entry.key as String));
        sb.write(': ');
        write(rulesExpr(entry.value));
      }
      sb.write('}');
    } else {
      throw UnsupportedError('Unsupported literal ${value.runtimeType}');
    }
  }
}
