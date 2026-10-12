import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'rich.dart';

/// A question and its answer ([rich] text), in one language. [id] gives the
/// anchor `#faq-<id>`.
typedef FaqItem = ({String id, String question, String answer});

/// Questions as native `details`: they open without JavaScript.
class FaqList extends StatelessComponent {
  /// The questions.
  final List<FaqItem> items;

  /// A list.
  const FaqList({super.key, required this.items});

  @override
  Component build(BuildContext context) {
    return div(classes: 'faq-list', [
      for (var faq in items)
        details(id: 'faq-${faq.id}', classes: 'faq', [
          summary([
            span(classes: 'faq-question', [.text(faq.question)]),
          ]),
          div(classes: 'faq-answer', [p(rich(faq.answer))]),
        ]),
    ]);
  }
}
