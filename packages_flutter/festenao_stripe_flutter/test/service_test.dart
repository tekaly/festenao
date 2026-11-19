import 'dart:convert';

import 'package:festenao_stripe_flutter/festenao_stripe_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake Stripe answering by path.
class FakeStripe {
  final requests = <http.Request>[];
  final answers = <String, Object? Function(http.Request request)>{};

  http.Client get client => MockClient((request) async {
    requests.add(request);
    var answer = answers[request.url.path];
    if (answer == null) {
      return http.Response(
        jsonEncode({
          'error': {'message': 'Unknown ${request.url.path}'},
        }),
        404,
        request: request,
      );
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(answer(request))),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });
}

Map<String, Object?> _session(
  String id, {
  String paymentStatus = 'paid',
  required List<Map<String, Object?>> items,
  bool hasMoreItems = false,
}) => {
  'id': id,
  'status': 'complete',
  'payment_status': paymentStatus,
  'amount_total': items.fold<int>(
    0,
    (sum, item) => sum + (item['amount_total'] as int),
  ),
  'currency': 'eur',
  'created': 1763500000,
  'customer_details': {'email': '$id@example.com', 'name': 'Name $id'},
  'metadata': {'orderId': 'order_$id'},
  'line_items': {'has_more': hasMoreItems, 'data': items},
};

Map<String, Object?> _item(String productId, int quantity, int unit) => {
  'id': 'li_${productId}_$quantity',
  'description': 'Desc $productId',
  'quantity': quantity,
  'amount_total': quantity * unit,
  'currency': 'eur',
  'price': {
    'id': 'price_$productId',
    'product': productId,
    'unit_amount': unit,
  },
};

void main() {
  late FakeStripe stripe;
  late StripeManagerService service;

  setUp(() {
    stripe = FakeStripe();
    service = StripeManagerService(
      client: StripeManagerClient(
        id: 'test',
        name: 'Test',
        secretKey: 'sk_test_0123456789abcdef',
      ),
      httpClient: stripe.client,
      baseUri: Uri.parse('http://localhost:1/v1'),
    );
  });
  tearDown(() async {
    await service.close();
  });

  test('readAll pages', () async {
    stripe.answers['/v1/products'] = (request) {
      var after = request.url.queryParameters['starting_after'];
      return after == null
          ? {
              'has_more': true,
              'data': [
                {'id': 'prod_1', 'name': 'One'},
                {'id': 'prod_2', 'name': 'Two'},
              ],
            }
          : {
              'has_more': false,
              'data': [
                {'id': 'prod_3', 'name': 'Three'},
              ],
            };
    };
    var products = await service.listProducts(active: true);
    expect(products.map((p) => p.id.v), ['prod_1', 'prod_2', 'prod_3']);
    expect(stripe.requests.map((r) => r.url.queryParameters), [
      {'limit': '100', 'active': 'true'},
      {'limit': '100', 'starting_after': 'prod_2', 'active': 'true'},
    ]);

    var list = await stripeManagerReadAll<int>(
      (after) async => ([1, 2], true),
      (item) => '$item',
      maxPages: 3,
    );
    expect(list.items.length, 6);
    expect(list.truncated, isTrue);
  });

  test('period stats', () async {
    stripe.answers['/v1/balance_transactions'] = (_) => {
      'has_more': false,
      'data': [
        {'id': 't1', 'type': 'charge', 'amount': 1000, 'fee': 40, 'net': 960},
        {'id': 't2', 'type': 'payment', 'amount': 2000, 'fee': 60, 'net': 1940},
        {'id': 't3', 'type': 'refund', 'amount': -1000, 'fee': 0, 'net': -1000},
        {'id': 't4', 'type': 'payout', 'amount': -1900, 'fee': 0},
      ].map((t) => {...t, 'currency': 'eur'}).toList(),
    };
    var stats = await service.getPeriodStats(StripeManagerPeriod.days30);
    expect(
      stripe.requests.single.url.queryParameters['created[gte]'],
      isNotNull,
    );
    var eur = stats.byCurrency['eur']!;
    expect(eur.paymentCount, 2);
    expect(eur.gross, 3000);
    expect(eur.fees, 100);
    expect(eur.refundCount, 1);
    expect(eur.refunded, 1000);
    expect(eur.paidOut, 1900);
    expect(eur.net, 1900);
  });

  test('sales by product, filter, csv', () async {
    stripe.answers['/v1/checkout/sessions'] = (request) {
      expect(request.url.queryParametersAll['expand[]'], ['data.line_items']);
      expect(request.url.queryParameters['status'], 'complete');
      return {
        'has_more': false,
        'data': [
          _session('cs_1', items: [_item('prod_book', 2, 1000)]),
          _session(
            'cs_2',
            items: [_item('prod_book', 1, 1000)],
            hasMoreItems: true,
          ),
          _session(
            'cs_3',
            paymentStatus: 'unpaid',
            items: [_item('prod_book', 9, 1000)],
          ),
          _session('cs_4', items: [_item('prod_other', 1, 500)]),
        ],
      };
    };
    stripe.answers['/v1/checkout/sessions/cs_2/line_items'] = (_) => {
      'has_more': false,
      'data': [_item('prod_book', 1, 1000), _item('prod_gift', 1, 300)],
    };
    var names = {'prod_book': 'Book'};
    var sales = await service.getSales(
      StripeManagerPeriod.all,
      productNames: names,
    );
    expect(sales.sessions.map((s) => s.id.v), ['cs_1', 'cs_2', 'cs_4']);
    var book = sales.byProduct['prod_book']!;
    expect(book.name, 'Book');
    expect(book.saleCount, 2);
    expect(book.quantity, 3);
    expect(book.amount, 3000);
    expect(sales.byProduct['prod_gift']!.name, 'Desc prod_gift');
    expect(sales.total, 2000 + 1000 + 500);

    var bookSales = await service.getSales(
      StripeManagerPeriod.all,
      productId: 'prod_book',
      productNames: names,
    );
    expect(bookSales.sessions.map((s) => s.id.v), ['cs_1', 'cs_2']);
    var csv = stripeManagerSalesCsv(bookSales, productNames: names);
    var lines = csv.trim().split('\n');
    expect(lines.first, startsWith('date,session,email'));
    // cs_1 one line, cs_2 two lines.
    expect(lines.length, 4);
    expect(
      lines[1],
      contains(
        'cs_1,cs_1@example.com,Name cs_1,prod_book,Book,2,20.00,eur,20.00',
      ),
    );
    expect(lines[1], endsWith('orderId=order_cs_1'));
  });

  test('writes', () async {
    stripe.answers['/v1/products'] = (_) => {'id': 'prod_new', 'name': 'New'};
    stripe.answers['/v1/products/prod_new'] = (_) => {
      'id': 'prod_new',
      'deleted': true,
    };
    stripe.answers['/v1/refunds'] = (_) => {
      'id': 're_1',
      'status': 'succeeded',
    };
    stripe.answers['/v1/payment_links/plink_1'] = (_) => {
      'id': 'plink_1',
      'active': false,
    };

    await service.createProduct(name: 'New', priceCents: 1250);
    expect(stripe.requests.last.bodyFields, {
      'name': 'New',
      'default_price_data[currency]': 'eur',
      'default_price_data[unit_amount]': '1250',
    });
    await service.deleteProduct('prod_new');
    expect(stripe.requests.last.method, 'DELETE');
    await service.refundCharge('ch_1', cents: 500);
    expect(stripe.requests.last.bodyFields, {
      'charge': 'ch_1',
      'amount': '500',
      'reason': 'requested_by_customer',
    });
    await service.setPaymentLinkActive('plink_1', false);
    expect(stripe.requests.last.bodyFields, {'active': 'false'});
  });

  test('account refused', () async {
    expect(await service.getAccountOrNull(), isNull);
  });

  test('format', () {
    expect(stripeManagerFormatAmount(1050), '10.50 €');
    expect(stripeManagerFormatAmount(-5, 'usd'), '-0.05 USD');
    expect(stripeManagerFormatAmount(null), '-');
    expect(stripeManagerFormatCsvAmount(123456), '1234.56');
    expect(stripeManagerParseCents('10,5'), 1050);
    expect(stripeManagerParseCents('0'), isNull);
    expect(stripeManagerParseCents('abc'), isNull);
    expect(
      stripeManagerCsv([
        ['a,b', 'c"d', null, 1],
      ]),
      '"a,b","c""d",,1\n',
    );
    var now = DateTime(2026, 11, 19, 12);
    expect(StripeManagerPeriod.thisYear.start(now), DateTime(2026));
    expect(StripeManagerPeriod.all.startSeconds(now), isNull);
  });
}
