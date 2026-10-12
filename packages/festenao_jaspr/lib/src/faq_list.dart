import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'rich.dart';

/// A question and its answer ([rich] text), in one language. [id] gives the
/// anchor `#faq-<id>`.
typedef FaqItem = ({String id, String question, String answer});

/// Questions as native `details`: they open without JavaScript; the first
/// [open] ones start open.
class FaqList extends StatelessComponent {
  /// The questions.
  final List<FaqItem> items;

  /// How many questions, from the first, start open.
  final int open;

  /// A list.
  const FaqList({super.key, required this.items, this.open = 0});

  @override
  Component build(BuildContext context) {
    return div(classes: 'faq-list', [
      for (var (index, faq) in items.indexed)
        details(
          id: 'faq-${faq.id}',
          classes: 'faq',
          attributes: {if (index < open) 'open': ''},
          [
            summary([
              span(classes: 'faq-question', [.text(faq.question)]),
            ]),
            div(classes: 'faq-answer', [p(rich(faq.answer))]),
          ],
        ),
    ]);
  }
}
