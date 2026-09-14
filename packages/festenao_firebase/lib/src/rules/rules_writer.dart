import 'rules_builder.dart';
import 'rules_expression.dart';

/// Writes [rules] as a firestore rules file.
String rulesToText(FirestoreRules rules) {
  var sb = StringBuffer();
  sb.writeln("rules_version = '${rules.rulesVersion}';");
  if (rules.headerComments.isNotEmpty) {
    sb.writeln();
    for (var comment in rules.headerComments) {
      _writeComment(sb, comment, '');
    }
  }
  sb.writeln('service cloud.firestore {');
  _writeMatch(sb, rules.documents, '  ');
  sb.writeln('}');
  return sb.toString();
}

void _writeComment(StringBuffer sb, String text, String indent) {
  for (var line in text.split('\n')) {
    if (line.isEmpty) {
      sb.writeln('$indent//');
    } else {
      sb.writeln('$indent// $line');
    }
  }
}

void _writeMatch(StringBuffer sb, RulesMatch match, String indent) {
  sb.writeln('${indent}match ${match.pattern} {');
  var childIndent = '$indent  ';
  RulesNode? previous;
  for (var item in match.items) {
    // A blank line around blocks (functions and matches), unless one was
    // explicitly requested; a comment sticks to what follows it.
    if (previous != null &&
        previous is! RulesBlankLine &&
        item is! RulesBlankLine &&
        ((previous is! RulesComment &&
                (item is RulesMatch || item is RulesFunction)) ||
            previous is RulesMatch ||
            previous is RulesFunction)) {
      sb.writeln();
    }
    _writeNode(sb, item, childIndent);
    previous = item;
  }
  sb.writeln('$indent}');
}

void _writeNode(StringBuffer sb, RulesNode node, String indent) {
  switch (node) {
    case RulesComment():
      _writeComment(sb, node.text, indent);
    case RulesBlankLine():
      sb.writeln();
    case RulesFunction():
      _writeFunction(sb, node, indent);
    case RulesAllow():
      _writeAllow(sb, node, indent);
    case RulesMatch():
      _writeMatch(sb, node, indent);
    default:
      throw UnsupportedError('Unsupported node ${node.runtimeType}');
  }
}

void _writeFunction(StringBuffer sb, RulesFunction function, String indent) {
  sb.writeln(
    '${indent}function ${function.name}(${function.params.join(', ')}) {',
  );
  var bodyIndent = '$indent  ';
  for (var let in function.lets) {
    sb.writeln('${bodyIndent}let ${let.name} = ${let.expr.toRulesText()};');
  }
  sb.writeln('${bodyIndent}return ${function.body.toRulesText()};');
  sb.writeln('$indent}');
}

void _writeAllow(StringBuffer sb, RulesAllow allow, String indent) {
  var methods = allow.methods.map((method) => method.name).join(', ');
  var condition = allow.condition;
  if (condition is RulesLiteral && condition.value == true) {
    sb.writeln('${indent}allow $methods: if true;');
  } else {
    sb.writeln('${indent}allow $methods: if ${condition.toRulesText()};');
  }
}
