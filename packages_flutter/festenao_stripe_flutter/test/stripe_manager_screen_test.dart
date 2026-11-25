import 'package:festenao_stripe_flutter/festenao_stripe_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';
import 'package:material_ui/material_ui.dart';

import 'service_test.dart' show FakeStripe;

/// Pumps frames until [finder] finds something (a progress indicator
/// animates forever: no pumpAndSettle); a real tick between frames runs the
/// callbacks of the sdb futures (completed out of the fake zone).
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets('home, products, live banner', (tester) async {
    var stripe = FakeStripe();
    stripe.answers['/v1/products'] = (_) => {
      'has_more': false,
      'data': [
        {'id': 'prod_1', 'name': 'The book', 'active': true},
      ],
    };
    var store = StripeManagerClientStore(
      factory: newSdbFactoryMemory(),
      builtInClients: [
        StripeManagerClient(
          id: 'builtin_test',
          name: 'Sandbox',
          secretKey: 'sk_test_0123456789abcdefTEST',
          builtIn: true,
        ),
        StripeManagerClient(
          id: 'builtin_live',
          name: 'Production',
          secretKey: 'sk_live_0123456789abcdefLIVE',
          builtIn: true,
        ),
      ],
    );
    await tester.runAsync(store.ready);

    await tester.pumpWidget(
      MaterialApp(
        home: StripeManagerScreen(
          store: store,
          serviceFactory: (client) => StripeManagerService(
            client: client,
            httpClient: stripe.client,
            baseUri: Uri.parse('http://localhost:1/v1'),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Sandbox'));
    expect(find.text('TEST'), findsOneWidget);
    expect(find.text('sk_test_…TEST'), findsOneWidget);
    // Never the whole key.
    expect(find.textContaining('0123456789'), findsNothing);
    expect(find.textContaining('real money'), findsNothing);

    await tester.tap(find.text('Products'));
    await pumpUntilFound(tester, find.text('The book'));
    expect(stripe.requests.single.url.path, '/v1/products');
    expect(
      stripe.requests.single.headers['authorization'],
      startsWith('Bearer '),
    );

    // Back home, switch to the live client: the banner shows.
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => store.selectClient('builtin_live'));
    await tester.pump();
    await pumpUntilFound(tester, find.textContaining('real money'));
    expect(find.text('LIVE'), findsOneWidget);

    await tester.runAsync(store.close);
  });

  testWidgets('a sale shows its product, a tap opens it', (tester) async {
    var stripe = FakeStripe();
    stripe.answers['/v1/products'] = (_) => {
      'has_more': false,
      'data': [
        {'id': 'prod_1', 'name': 'Membership 2026', 'active': true},
      ],
    };
    stripe.answers['/v1/checkout/sessions'] = (_) => {
      'has_more': false,
      'data': [
        {
          'id': 'cs_1',
          'status': 'complete',
          'payment_status': 'paid',
          'amount_total': 2550,
          'currency': 'eur',
          'created': 1763500000,
          'customer_details': {'email': 'jo@example.com', 'name': 'Jo'},
          'line_items': {
            'has_more': false,
            'data': [
              {
                'id': 'li_1',
                'description': 'Cotisation',
                'quantity': 1,
                'amount_total': 2550,
                'currency': 'eur',
                'price': {
                  'id': 'price_1',
                  'product': 'prod_1',
                  'unit_amount': 2550,
                  'nickname': 'Cotisation Doe Jo',
                },
              },
            ],
          },
        },
      ],
    };
    stripe.answers['/v1/products/prod_1'] = (_) => {
      'id': 'prod_1',
      'name': 'Membership 2026',
      'active': true,
    };
    stripe.answers['/v1/prices'] = (_) => {
      'has_more': false,
      'data': <Object?>[],
    };
    var service = StripeManagerService(
      client: StripeManagerClient(
        id: 'test',
        name: 'Sandbox',
        secretKey: 'sk_test_0123456789abcdefTEST',
      ),
      httpClient: stripe.client,
      baseUri: Uri.parse('http://localhost:1/v1'),
    );
    await tester.pumpWidget(
      MaterialApp(home: StripeManagerSalesScreen(service: service)),
    );
    // The product name, not the line description.
    await pumpUntilFound(tester, find.text('1 × Membership 2026'));

    // The sale: its line shows the product name, id and price nickname.
    await tester.tap(find.text('1 × Membership 2026'));
    // The sheet slides in (its animation starts on the next frame).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    var productLine = find.textContaining('Product prod_1');
    expect(productLine, findsOneWidget);
    expect(find.textContaining('Price Cotisation Doe Jo'), findsOneWidget);

    await tester.ensureVisible(productLine);
    await tester.pump();
    await tester.tap(productLine);
    await pumpUntilFound(tester, find.byType(StripeManagerProductScreen));
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(StripeManagerProductScreen),
        matching: find.text('Membership 2026'),
      ),
    );
    expect(
      stripe.requests.map((request) => request.url.path),
      contains('/v1/products/prod_1'),
    );
  });
}
