import 'package:http/http.dart' as http;
import 'package:tekartik_stripe_api/stripe_api.dart';

import 'client.dart';
import 'format.dart';
import 'paged.dart';

/// The most pages a list reads (100 objects each).
const stripeManagerMaxPages = 20;

/// A page size.
const _pageLimit = 100;

/// The objects of every page read by [readPage] (100 a page, at most
/// [maxPages]): `(items, hasMore)` of the page after the id given.
Future<StripeManagerList<T>> stripeManagerReadAll<T>(
  Future<(List<T>, bool)> Function(String? startingAfter) readPage,
  String? Function(T item) idOf, {
  int maxPages = stripeManagerMaxPages,
}) async {
  var items = <T>[];
  String? startingAfter;
  for (var page = 0; page < maxPages; page++) {
    var (data, hasMore) = await readPage(startingAfter);
    items.addAll(data);
    if (!hasMore || data.isEmpty) {
      return StripeManagerList(items, truncated: false);
    }
    startingAfter = idOf(data.last);
    if (startingAfter == null) {
      break;
    }
  }
  return StripeManagerList(items, truncated: true);
}

/// Objects read from several pages.
class StripeManagerList<T> {
  /// The objects, newest first.
  final List<T> items;

  /// true when the page limit stopped the read (more exist).
  final bool truncated;

  /// A list of [items].
  StripeManagerList(this.items, {required this.truncated});
}

/// Amounts of a currency over a period (cents).
class StripeManagerCurrencyStats {
  /// `eur`...
  final String currency;

  /// Payments count.
  var paymentCount = 0;

  /// Payments gross amount.
  var gross = 0;

  /// Stripe fees (every transaction).
  var fees = 0;

  /// Refunds count.
  var refundCount = 0;

  /// Refunded amount (positive).
  var refunded = 0;

  /// Paid out amount (positive).
  var paidOut = 0;

  /// Net of payments and refunds (gross - fees - refunded).
  var net = 0;

  /// Stats of [currency].
  StripeManagerCurrencyStats(this.currency);
}

/// The dashboard of a period.
class StripeManagerPeriodStats {
  /// By currency.
  final Map<String, StripeManagerCurrencyStats> byCurrency;

  /// The transactions read.
  final int transactionCount;

  /// More transactions than read.
  final bool truncated;

  /// Stats of a period.
  StripeManagerPeriodStats({
    required this.byCurrency,
    required this.transactionCount,
    required this.truncated,
  });
}

/// The sales of a product in a period.
class StripeManagerProductSales {
  /// The product id, null for a line without product.
  final String? productId;

  /// The product name (the line description when unknown).
  final String name;

  /// Sales (paid sessions) count.
  var saleCount = 0;

  /// Units sold.
  var quantity = 0;

  /// Amount (cents).
  var amount = 0;

  /// `eur`...
  String? currency;

  /// Sales of [productId].
  StripeManagerProductSales({required this.productId, required this.name});
}

/// The paid Checkout Sessions of a period with their totals.
class StripeManagerSales {
  /// The sessions (line items loaded), newest first.
  final List<StripeApiCheckoutSession> sessions;

  /// By product id (null key: lines without product).
  final Map<String?, StripeManagerProductSales> byProduct;

  /// More sessions than read.
  final bool truncated;

  /// Sales of [sessions].
  StripeManagerSales({
    required this.sessions,
    required this.byProduct,
    required this.truncated,
  });

  /// Total amount of [sessions] (cents, every currency added).
  int get total =>
      sessions.fold(0, (sum, session) => sum + (session.amountTotal.v ?? 0));
}

/// The calls of the manager for one [client].
///
/// [httpClient] and [baseUri] are for tests; call [close] when done.
class StripeManagerService {
  /// The client.
  final StripeManagerClient client;

  /// The api.
  final StripeApi api;

  /// A service of [client].
  StripeManagerService({
    required this.client,
    http.Client? httpClient,
    Uri? baseUri,
  }) : api = StripeApi(
         credentials: StripeApiCredentials(secretKey: client.secretKey),
         baseClient: httpClient,
         baseUri: baseUri,
       );

  final _pagedLists = <String, StripeManagerPagedList<Object?>>{};

  /// The paged list [key] of this client, kept while the service lives (the
  /// client stays selected): [readPage] and [idOf] are used the first time.
  StripeManagerPagedList<T> pagedList<T>(
    String key, {
    required StripeManagerPageReader<T> readPage,
    required String? Function(T item) idOf,
  }) =>
      (_pagedLists[key] ??= StripeManagerPagedList<T>(
            readPage: readPage,
            idOf: idOf,
          ))
          as StripeManagerPagedList<T>;

  /// Closes the api, forgets the paged lists.
  Future<void> close() async {
    for (var list in _pagedLists.values) {
      list.dispose();
    }
    _pagedLists.clear();
    await api.close();
  }

  /// The Payment Links, active ones or inactive ones ([active] false), read
  /// page by page ([pageSize] a page, newest first) with their line items
  /// (the only date of a link is the one of its prices), cached per [active].
  StripeManagerPagedList<StripeApiPaymentLink> pagedPaymentLinks({
    required bool active,
    int pageSize = 50,
  }) => pagedList<StripeApiPaymentLink>(
    'payment_links:$active',
    readPage: (startingAfter) async {
      var list = await api.listPaymentLinks(
        StripeApiPaymentLinkListOptions()
          ..limit.v = pageSize
          ..active.v = active
          ..startingAfter.v = startingAfter
          ..expand.v = ['data.line_items'],
      );
      return (
        list.data.v ?? const <StripeApiPaymentLink>[],
        list.hasMore.v ?? false,
      );
    },
    idOf: (link) => link.id.v,
  );

  /// The balance (a cheap call that checks the key too).
  Future<StripeApiBalance> getBalance() => api.getBalance();

  /// The account, null when the key may not read it (a restricted key).
  Future<StripeApiAccount?> getAccountOrNull() async {
    try {
      return await api.getAccount();
    } catch (_) {
      return null;
    }
  }

  /// The balance transactions since [startSeconds] (all when null).
  Future<StripeManagerList<StripeApiBalanceTransaction>>
  listBalanceTransactions({int? startSeconds, String? payoutId}) =>
      stripeManagerReadAll((startingAfter) async {
        var list = await api.listBalanceTransactions(
          StripeApiBalanceTransactionListOptions()
            ..limit.v = _pageLimit
            ..payout.v = payoutId
            ..createdGte.v = startSeconds
            ..startingAfter.v = startingAfter,
        );
        return (list.data.v ?? const [], list.hasMore.v ?? false);
      }, (item) => item.id.v);

  /// The stats of [period] from its balance transactions.
  Future<StripeManagerPeriodStats> getPeriodStats(
    StripeManagerPeriod period,
  ) async {
    var list = await listBalanceTransactions(
      startSeconds: period.startSeconds(),
    );
    return stripeManagerComputePeriodStats(
      list.items,
      truncated: list.truncated,
    );
  }

  /// The products, active ones or archived ones ([active] false), all when
  /// null.
  Future<List<StripeApiProduct>> listProducts({bool? active}) async =>
      (await stripeManagerReadAll((startingAfter) async {
        var list = await api.listProducts(
          StripeApiProductListOptions()
            ..limit.v = _pageLimit
            ..active.v = active
            ..startingAfter.v = startingAfter,
        );
        return (
          list.data.v ?? const <StripeApiProduct>[],
          list.hasMore.v ?? false,
        );
      }, (item) => item.id.v)).items;

  /// The prices of [productId] (active and inactive).
  Future<List<StripeApiPrice>> listPrices(String productId) async =>
      (await stripeManagerReadAll((startingAfter) async {
        var list = await api.listPrices(
          StripeApiPriceListOptions()
            ..productId.v = productId
            ..limit.v = _pageLimit
            ..startingAfter.v = startingAfter,
        );
        return (
          list.data.v ?? const <StripeApiPrice>[],
          list.hasMore.v ?? false,
        );
      }, (item) => item.id.v)).items;

  /// Creates a product [name], with a one time price of [priceCents] in
  /// [currency] made its default one when given.
  Future<StripeApiProduct> createProduct({
    required String name,
    String? description,
    int? priceCents,
    String currency = stripeCurrencyEuro,
  }) => api.createProduct(
    StripeApiProductCreate()
      ..name.v = name
      ..description.v = description
      ..defaultPriceData.v = priceCents == null
          ? null
          : (StripeApiProductDefaultPriceData()
              ..currency.v = currency
              ..amount.v = priceCents),
  );

  /// Updates the [name] and [description] of [productId].
  Future<StripeApiProduct> updateProduct(
    String productId, {
    String? name,
    String? description,
  }) => api.updateProduct(
    productId,
    StripeApiProductUpdate()
      ..name.v = name
      ..description.v = description,
  );

  /// Archives ([active] false) or restores [productId].
  Future<StripeApiProduct> setProductActive(String productId, bool active) =>
      api.updateProduct(productId, StripeApiProductUpdate()..active.v = active);

  /// Makes [priceId] the default price of [productId].
  Future<StripeApiProduct> setDefaultPrice(String productId, String priceId) =>
      api.updateProduct(
        productId,
        StripeApiProductUpdate()..defaultPrice.v = priceId,
      );

  /// Deletes [productId] (Stripe refuses it when it has prices).
  Future<StripeApiDeleted> deleteProduct(String productId) =>
      api.deleteProduct(productId);

  /// A one time price of [cents] for [productId].
  Future<StripeApiPrice> createPrice({
    required String productId,
    required int cents,
    String currency = stripeCurrencyEuro,
    String? nickname,
  }) => api.createPrice(
    StripeApiPriceCreate()
      ..productId.v = productId
      ..amount.v = cents
      ..currency.v = currency
      ..nickname.v = nickname,
  );

  /// Activates or deactivates [priceId].
  Future<StripeApiPrice> setPriceActive(String priceId, bool active) =>
      api.updatePrice(priceId, StripeApiPriceUpdate()..active.v = active);

  /// The paid Checkout Sessions of [period] with their line items, those
  /// selling [productId] only when given.
  Future<StripeManagerSales> getSales(
    StripeManagerPeriod period, {
    String? productId,
    Map<String, String> productNames = const {},
  }) async {
    var list = await stripeManagerReadAll((startingAfter) async {
      var page = await api.listCheckoutSessions(
        StripeApiCheckoutSessionListOptions()
          ..status.v = stripeCheckoutSessionStatusComplete
          ..limit.v = _pageLimit
          ..createdGte.v = period.startSeconds()
          ..expand.v = ['data.line_items']
          ..startingAfter.v = startingAfter,
      );
      return (
        page.data.v ?? const <StripeApiCheckoutSession>[],
        page.hasMore.v ?? false,
      );
    }, (item) => item.id.v);
    var sessions = <StripeApiCheckoutSession>[];
    for (var session in list.items) {
      if (session.paymentStatus.v != stripeCheckoutSessionPaymentStatusPaid) {
        continue;
      }
      // An expanded list holds the first items only.
      if (session.lineItems.v?.hasMore.v ?? false) {
        session.lineItems.v = await api.listCheckoutSessionLineItems(
          session.id.v!,
        );
      }
      sessions.add(session);
    }
    return stripeManagerComputeSales(
      sessions,
      productId: productId,
      productNames: productNames,
      truncated: list.truncated,
    );
  }

  /// The charges since [startSeconds] (all when null).
  Future<StripeManagerList<StripeApiCharge>> listCharges({int? startSeconds}) =>
      stripeManagerReadAll((startingAfter) async {
        var list = await api.listCharges(
          StripeApiChargeListOptions()
            ..limit.v = _pageLimit
            ..createdGte.v = startSeconds
            ..startingAfter.v = startingAfter,
        );
        return (
          list.data.v ?? const <StripeApiCharge>[],
          list.hasMore.v ?? false,
        );
      }, (item) => item.id.v);

  /// Refunds [chargeId], all of it unless [cents].
  Future<StripeApiRefund> refundCharge(String chargeId, {int? cents}) =>
      api.createRefund(
        StripeApiRefundCreate()
          ..charge.v = chargeId
          ..amount.v = cents
          ..reason.v = 'requested_by_customer',
      );

  /// The Payment Links, active ones or inactive ones ([active] false), all
  /// when null.
  Future<StripeManagerList<StripeApiPaymentLink>> listPaymentLinks({
    bool? active,
  }) => stripeManagerReadAll((startingAfter) async {
    var list = await api.listPaymentLinks(
      StripeApiPaymentLinkListOptions()
        ..limit.v = _pageLimit
        ..active.v = active
        ..startingAfter.v = startingAfter,
    );
    return (
      list.data.v ?? const <StripeApiPaymentLink>[],
      list.hasMore.v ?? false,
    );
  }, (item) => item.id.v);

  /// The line items of [paymentLinkId].
  Future<List<StripeApiLineItem>> listPaymentLinkLineItems(
    String paymentLinkId,
  ) async =>
      (await api.listPaymentLinkLineItems(paymentLinkId)).data.v ?? const [];

  /// The completed Checkout Sessions of [paymentLinkId].
  Future<List<StripeApiCheckoutSession>> listPaymentLinkSessions(
    String paymentLinkId,
  ) async => (await stripeManagerReadAll((startingAfter) async {
    var page = await api.listCheckoutSessions(
      StripeApiCheckoutSessionListOptions()
        ..paymentLink.v = paymentLinkId
        ..status.v = stripeCheckoutSessionStatusComplete
        ..limit.v = _pageLimit
        ..startingAfter.v = startingAfter,
    );
    return (
      page.data.v ?? const <StripeApiCheckoutSession>[],
      page.hasMore.v ?? false,
    );
  }, (item) => item.id.v)).items;

  /// Deactivates [paymentLinkId] (or activates it back).
  Future<StripeApiPaymentLink> setPaymentLinkActive(
    String paymentLinkId,
    bool active,
  ) => api.updatePaymentLink(
    paymentLinkId,
    StripeApiPaymentLinkUpdate()..active.v = active,
  );

  /// The payouts since [startSeconds] (all when null).
  Future<StripeManagerList<StripeApiPayout>> listPayouts({int? startSeconds}) =>
      stripeManagerReadAll((startingAfter) async {
        var list = await api.listPayouts(
          StripeApiPayoutListOptions()
            ..limit.v = _pageLimit
            ..createdGte.v = startSeconds
            ..startingAfter.v = startingAfter,
        );
        return (
          list.data.v ?? const <StripeApiPayout>[],
          list.hasMore.v ?? false,
        );
      }, (item) => item.id.v);
}

/// The stats of balance [transactions] by currency.
StripeManagerPeriodStats stripeManagerComputePeriodStats(
  List<StripeApiBalanceTransaction> transactions, {
  bool truncated = false,
}) {
  var byCurrency = <String, StripeManagerCurrencyStats>{};
  for (var transaction in transactions) {
    var currency = transaction.currency.v ?? stripeCurrencyEuro;
    var stats = byCurrency[currency] ??= StripeManagerCurrencyStats(currency);
    var amount = transaction.amount.v ?? 0;
    var fee = transaction.fee.v ?? 0;
    stats.fees += fee;
    switch (transaction.type.v) {
      case stripeBalanceTransactionTypeCharge ||
          stripeBalanceTransactionTypePayment:
        stats.paymentCount++;
        stats.gross += amount;
        stats.net += amount - fee;
      case stripeBalanceTransactionTypeRefund || 'payment_refund':
        stats.refundCount++;
        stats.refunded -= amount;
        stats.net += amount - fee;
      case stripeBalanceTransactionTypePayout:
        stats.paidOut -= amount;
      default:
        // Fees, adjustments...: counted in the net.
        if (transaction.type.v != 'payout_cancel' &&
            transaction.type.v != 'payout_failure') {
          stats.net += amount - fee;
        }
    }
  }
  return StripeManagerPeriodStats(
    byCurrency: byCurrency,
    transactionCount: transactions.length,
    truncated: truncated,
  );
}

/// The sales of paid [sessions] (line items loaded) by product, those
/// selling [productId] only when given.
StripeManagerSales stripeManagerComputeSales(
  List<StripeApiCheckoutSession> sessions, {
  String? productId,
  Map<String, String> productNames = const {},
  bool truncated = false,
}) {
  var byProduct = <String?, StripeManagerProductSales>{};
  var kept = <StripeApiCheckoutSession>[];
  for (var session in sessions) {
    var items = session.lineItems.v?.data.v ?? const <StripeApiLineItem>[];
    if (productId != null &&
        !items.any((item) => item.price.v?.productId.v == productId)) {
      continue;
    }
    kept.add(session);
    var counted = <String?>{};
    for (var item in items) {
      var itemProductId = item.price.v?.productId.v;
      var sales = byProduct[itemProductId] ??= StripeManagerProductSales(
        productId: itemProductId,
        name:
            productNames[itemProductId] ??
            item.description.v ??
            itemProductId ??
            '?',
      );
      if (counted.add(itemProductId)) {
        sales.saleCount++;
      }
      sales.quantity += item.quantity.v ?? 0;
      sales.amount += item.amountTotal.v ?? 0;
      sales.currency ??= item.currency.v;
    }
  }
  return StripeManagerSales(
    sessions: kept,
    byProduct: byProduct,
    truncated: truncated,
  );
}

/// The csv of [sales]: one line per line item.
String stripeManagerSalesCsv(
  StripeManagerSales sales, {
  Map<String, String> productNames = const {},
}) {
  var rows = <List<Object?>>[
    [
      'date',
      'session',
      'email',
      'name',
      'product_id',
      'product',
      'quantity',
      'amount',
      'currency',
      'session_total',
      'payment_link',
      'metadata',
    ],
  ];
  for (var session in sales.sessions) {
    var details = session.customerDetails.v;
    var metadata = session.metadata.v;
    var metadataText = metadata == null || metadata.isEmpty
        ? ''
        : metadata.entries.map((e) => '${e.key}=${e.value}').join(' ');
    var items = session.lineItems.v?.data.v ?? const <StripeApiLineItem>[];
    for (var item in items.isEmpty ? <StripeApiLineItem?>[null] : items) {
      var itemProductId = item?.price.v?.productId.v;
      rows.add([
        stripeManagerFormatDateTime(session.created.v),
        session.id.v,
        details?.email.v ?? session.customerEmail.v,
        details?.name.v,
        itemProductId,
        productNames[itemProductId] ?? item?.description.v,
        item?.quantity.v,
        stripeManagerFormatCsvAmount(item?.amountTotal.v),
        item?.currency.v ?? session.currency.v,
        stripeManagerFormatCsvAmount(session.amountTotal.v),
        session.paymentLink.v,
        metadataText,
      ]);
    }
  }
  return stripeManagerCsv(rows);
}

/// What a Payment Link list shows, from its expanded line items.
class StripeManagerPaymentLinkSummary {
  /// The link.
  final StripeApiPaymentLink link;

  final List<StripeApiLineItem>? _items;

  /// A summary of [link], of its expanded line items unless [items] are
  /// given (read apart).
  StripeManagerPaymentLinkSummary(this.link, {this._items});

  /// The line items (empty when neither expanded nor given).
  List<StripeApiLineItem> get items =>
      _items ?? link.lineItemList.v?.data.v ?? const <StripeApiLineItem>[];

  /// The newest price date (unix seconds): a link has no date of its own,
  /// a price made for the link gives its creation date.
  int? get date {
    int? newest;
    for (var item in items) {
      var created = item.price.v?.created.v;
      if (created != null && (newest == null || created > newest)) {
        newest = created;
      }
    }
    return newest;
  }

  /// The first price nickname, else the first item description, `+n` for
  /// the other items.
  String? get title {
    if (items.isEmpty) {
      return null;
    }
    var first = items.first;
    var text = first.price.v?.nickname.v ?? first.description.v ?? '?';
    if (items.length > 1) {
      text = '$text +${items.length - 1}';
    }
    return text;
  }

  /// The total of the items, cents.
  int? get amount => items.isEmpty
      ? null
      : items.fold<int>(0, (sum, item) => sum + (item.amountTotal.v ?? 0));

  /// The currency of the first item.
  String? get currency => items.isEmpty ? null : items.first.currency.v;

  /// `paid 1/1` for a link paid a limited number of times.
  String? get paidText {
    var sessions = link.restrictions.v?.completedSessions.v;
    var limit = sessions?.limit.v;
    if (limit == null) {
      return null;
    }
    return 'paid ${sessions?.count.v ?? 0}/$limit';
  }
}
