import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'widgets.dart';

class _SalesData {
  final StripeManagerSales sales;
  final Map<String, String> productNames;

  _SalesData(this.sales, this.productNames);
}

/// The paid Checkout Sessions of a period, by product, csv export.
class StripeManagerSalesScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The product shown first, all when null.
  final String? productId;

  /// The sales of [service].
  const StripeManagerSalesScreen({
    super.key,
    required this.service,
    this.productId,
  });

  @override
  State<StripeManagerSalesScreen> createState() =>
      _StripeManagerSalesScreenState();
}

class _StripeManagerSalesScreenState extends State<StripeManagerSalesScreen> {
  var _period = StripeManagerPeriod.days30;
  late String? _productId = widget.productId;
  List<StripeApiProduct>? _products;
  _SalesData? _last;

  StripeManagerService get service => widget.service;

  Future<_SalesData> _load() async {
    var products = _products ??= await service.listProducts();
    var productNames = <String, String>{
      for (var product in products)
        ?product.id.v: product.name.v ?? product.id.v ?? '',
    };
    var sales = await service.getSales(
      _period,
      productId: _productId,
      productNames: productNames,
    );
    return _last = _SalesData(sales, productNames);
  }

  Future<void> _copyCsv() async {
    var last = _last;
    if (last == null) {
      return;
    }
    await stripeManagerCopy(
      context,
      stripeManagerSalesCsv(last.sales, productNames: last.productNames),
      what: 'CSV (${last.sales.sessions.length} sales)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Sales',
      actions: [
        IconButton(
          tooltip: 'Copy as CSV',
          icon: const Icon(Icons.table_view),
          onPressed: _copyCsv,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StripeManagerPeriodSelector(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                if (_products case var products?)
                  DropdownButton<String?>(
                    value: _productId,
                    items: [
                      const DropdownMenuItem(child: Text('All products')),
                      for (var product in products)
                        DropdownMenuItem(
                          value: product.id.v,
                          child: Text(product.name.v ?? product.id.v ?? '?'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _productId = value),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StripeManagerFutureView<_SalesData>(
              reloadKey: (_period, _productId),
              load: () async {
                var data = await _load();
                if (mounted) {
                  // The product list for the filter.
                  setState(() {});
                }
                return data;
              },
              builder: (context, data, reload) {
                var sales = data.sales;
                return ListView(
                  children: [
                    const StripeManagerSectionTitle('By product'),
                    if (sales.byProduct.isEmpty)
                      const ListTile(
                        dense: true,
                        title: Text('No paid sale in the period'),
                      ),
                    for (var product in sales.byProduct.values)
                      ListTile(
                        dense: true,
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.saleCount} sales, ${product.quantity} '
                          'units',
                        ),
                        trailing: Text(
                          stripeManagerFormatAmount(
                            product.amount,
                            product.currency,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (sales.sessions.isNotEmpty)
                      ListTile(
                        dense: true,
                        title: Text('Total, ${sales.sessions.length} sales'),
                        trailing: Text(
                          stripeManagerFormatAmount(
                            sales.total,
                            sales.sessions.first.currency.v,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (sales.truncated)
                      const ListTile(
                        dense: true,
                        title: Text('More sales exist: shorten the period'),
                      ),
                    const StripeManagerSectionTitle('Sales'),
                    for (var session in sales.sessions)
                      _SessionTile(
                        session: session,
                        productNames: data.productNames,
                      ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final StripeApiCheckoutSession session;
  final Map<String, String> productNames;

  const _SessionTile({required this.session, required this.productNames});

  @override
  Widget build(BuildContext context) {
    var details = session.customerDetails.v;
    var items = session.lineItems.v?.data.v ?? const <StripeApiLineItem>[];
    var who = details?.name.v ?? details?.email.v ?? session.customerEmail.v;
    return ListTile(
      title: Text(
        '${stripeManagerFormatDateTime(session.created.v)}  ${who ?? ''}',
      ),
      subtitle: Text(
        items
            .map(
              (item) =>
                  '${item.quantity.v ?? 1} × '
                  '${productNames[item.price.v?.productId.v] ?? item.description.v ?? '?'}',
            )
            .join(', '),
      ),
      trailing: Text(
        stripeManagerFormatAmount(session.amountTotal.v, session.currency.v),
      ),
      onTap: () => showStripeManagerSession(context, session, productNames),
    );
  }
}

/// Shows the details of a Checkout [session].
Future<void> showStripeManagerSession(
  BuildContext context,
  StripeApiCheckoutSession session,
  Map<String, String> productNames,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) {
    var details = session.customerDetails.v;
    var items = session.lineItems.v?.data.v ?? const <StripeApiLineItem>[];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          StripeManagerInfoTile(
            label: 'Date',
            value: stripeManagerFormatDateTime(session.created.v),
          ),
          StripeManagerInfoTile(
            label: 'Total',
            value: stripeManagerFormatAmount(
              session.amountTotal.v,
              session.currency.v,
            ),
          ),
          StripeManagerInfoTile(label: 'Name', value: details?.name.v),
          StripeManagerInfoTile(
            label: 'Email',
            value: details?.email.v ?? session.customerEmail.v,
            copy: true,
          ),
          StripeManagerInfoTile(label: 'Phone', value: details?.phone.v),
          for (var item in items)
            StripeManagerInfoTile(
              label:
                  productNames[item.price.v?.productId.v] ??
                  item.description.v ??
                  '?',
              value:
                  '${item.quantity.v ?? 1} × '
                  '${stripeManagerFormatAmount(item.price.v?.amount.v, item.currency.v)}'
                  ' = ${stripeManagerFormatAmount(item.amountTotal.v, item.currency.v)}',
            ),
          if (session.metadata.v case var metadata? when metadata.isNotEmpty)
            StripeManagerInfoTile(
              label: 'Metadata',
              value: metadata.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
            ),
          StripeManagerInfoTile(
            label: 'Session',
            value: session.id.v,
            copy: true,
          ),
          StripeManagerInfoTile(
            label: 'Payment link',
            value: session.paymentLink.v,
            copy: true,
          ),
          StripeManagerInfoTile(
            label: 'Payment intent',
            value: session.paymentIntent.v,
            copy: true,
          ),
        ],
      ),
    );
  },
);
