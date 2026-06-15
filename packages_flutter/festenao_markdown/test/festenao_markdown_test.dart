import 'package:festenao_markdown/gpt_markdown.dart' as gpt;
import 'package:festenao_markdown/markdown.dart' as original;
import 'package:festenao_markdown/markdown_plus.dart' as plus;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('markdown widgets', () {
    testWidgets('FestenaoMarkdownWidget (gpt)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: gpt.FestenaoMarkdownWidget(data: '# Hello')),
        ),
      );
      expect(find.byType(gpt.FestenaoMarkdownWidget), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('FestenaoMarkdownWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: original.FestenaoMarkdownWidget(data: '# Hello'),
          ),
        ),
      );
      expect(find.byType(original.FestenaoMarkdownWidget), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('FestenaoMarkdownPlusWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: plus.FestenaoMarkdownWidget(data: '# Hello')),
        ),
      );
      expect(find.byType(plus.FestenaoMarkdownWidget), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });
  });
}
