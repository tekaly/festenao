import 'package:cv/cv.dart';
import 'package:festenao_stripe_flutter/festenao_stripe_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import 'service_test.dart' show FakeStripe;
import 'stripe_manager_screen_test.dart' show pumpUntilFound;

/// A link of [index] (newest first), its price made [index] hours before
/// 2023-11-14 22:13 UTC.
Map<String, Object?> _link(int index) => {
  'id': 'plink_$index',
  'url': 'https://buy.stripe.com/test_$index',
  'active': true,
  'metadata': {'membershipId': 'm$index'},
  if (index.isEven)
    'restrictions': {
      'completed_sessions': {'count': index % 4 == 0 ? 1 : 0, 'limit': 1},
    },
  'line_items': {
    'has_more': false,
    'data': [
      {
        'id': 'li_$index',
        'description': 'Cotisation',
        'quantity': 1,
        'amount_total': 1000 + index,
        'currency': 'eur',
        'price': {
          'id': 'price_$index',
          'created': 1700000000 - index * 3600,
          'nickname': 'Cotisation Member $index',
        },
      },
    ],
  },
};

/// 120 links, served [limit] by [limit] after `starting_after`.
Object? _linksPage(http.Request request) {
  var query = request.url.queryParameters;
  var limit = int.parse(query['limit']!);
  var start = 0;
  if (query['starting_after'] case var after?) {
    start = int.parse(after.substring('plink_'.length)) + 1;
  }
  var end = (start + limit).clamp(0, 120);
  return {
    'has_more': end < 120,
    'data': [for (var i = start; i < end; i++) _link(i)],
  };
}

void main() {
  var client = StripeManagerClient(
    id: 'test',
    name: 'Sandbox',
    secretKey: 'sk_test_0123456789abcdefTEST',
  );

  test('paged list: pages, cache, refresh, error', () async {
    var stripe = FakeStripe()..answers['/v1/payment_links'] = _linksPage;
    var service = StripeManagerService(
      client: client,
      httpClient: stripe.client,
      baseUri: Uri.parse('http://localhost:1/v1'),
    );
    var list = service.pagedPaymentLinks(active: true);
    expect(list.isFresh, isTrue);
    await list.loadMore();
    expect(list.items.length, 50);
    expect(list.hasMore, isTrue);
    var query = stripe.requests.single.url.queryParametersAll;
    expect(query['expand[]'], ['data.line_items']);
    expect(query['active'], ['true']);

    // The same list while the service lives.
    expect(identical(service.pagedPaymentLinks(active: true), list), isTrue);
    expect(identical(service.pagedPaymentLinks(active: false), list), isFalse);

    await list.loadMore();
    await list.loadMore();
    expect(list.items.length, 120);
    expect(list.hasMore, isFalse);
    expect(
      stripe.requests.last.url.queryParameters['starting_after'],
      'plink_99',
    );
    // Nothing more to read.
    await list.loadMore();
    expect(stripe.requests.length, 3);

    stripe.answers.remove('/v1/payment_links');
    await list.refresh();
    expect(list.items, isEmpty);
    expect(list.error, isNotNull);
    stripe.answers['/v1/payment_links'] = _linksPage;
    await list.loadMore();
    expect(list.error, isNull);
    expect(list.items.length, 50);
    await service.close();
  });

  test('summary: date, title, amount, paid', () {
    initStripeApiModels();
    var link = _link(4).cv<StripeApiPaymentLink>();
    var summary = StripeManagerPaymentLinkSummary(link);
    expect(summary.title, 'Cotisation Member 4');
    expect(summary.date, 1700000000 - 4 * 3600);
    expect(summary.amount, 1004);
    expect(summary.paidText, 'paid 1/1');
    expect(
      StripeManagerPaymentLinkSummary(_link(1).cv<StripeApiPaymentLink>())
          .paidText,
      isNull,
    );
  });

  testWidgets('links screen: first page at once, next page on scroll', (
    tester,
  ) async {
    var stripe = FakeStripe()..answers['/v1/payment_links'] = _linksPage;
    var service = StripeManagerService(
      client: client,
      httpClient: stripe.client,
      baseUri: Uri.parse('http://localhost:1/v1'),
    );
    await tester.pumpWidget(
      MaterialApp(home: StripeManagerPaymentLinksScreen(service: service)),
    );
    await pumpUntilFound(tester, find.text('Cotisation Member 0'));
    expect(find.text('10.00 €'), findsOneWidget);
    expect(find.textContaining('paid 1/1'), findsWidgets);
    expect(find.textContaining('paid 0/1'), findsWidgets);
    expect(find.textContaining('membershipId: m0'), findsOneWidget);
    expect(stripe.requests.length, 1);

    // Scrolled to the end: the next page is read.
    var scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Cotisation Member 49'),
      300,
      scrollable: scrollable,
    );
    var list = service.pagedPaymentLinks(active: true);
    for (var i = 0; i < 50 && list.items.length < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(stripe.requests.length, greaterThanOrEqualTo(2));
    expect(list.items.length, greaterThanOrEqualTo(100));
    await tester.scrollUntilVisible(
      find.text('Cotisation Member 50'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Cotisation Member 50'), findsOneWidget);
    await service.close();
  });
}
