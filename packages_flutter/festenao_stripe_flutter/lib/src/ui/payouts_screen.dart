import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'widgets.dart';

/// The payouts of a period.
class StripeManagerPayoutsScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The payouts of [service].
  const StripeManagerPayoutsScreen({super.key, required this.service});

  @override
  State<StripeManagerPayoutsScreen> createState() =>
      _StripeManagerPayoutsScreenState();
}

class _StripeManagerPayoutsScreenState
    extends State<StripeManagerPayoutsScreen> {
  var _period = StripeManagerPeriod.days365;

  StripeManagerService get service => widget.service;

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payouts',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: Text('Payouts to the bank')),
                StripeManagerPeriodSelector(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
              ],
            ),
          ),
          Expanded(
            child: StripeManagerFutureView<StripeManagerList<StripeApiPayout>>(
              reloadKey: _period,
              load: () =>
                  service.listPayouts(startSeconds: _period.startSeconds()),
              builder: (context, list, reload) {
                if (list.items.isEmpty) {
                  return const Center(child: Text('No payout in the period'));
                }
                var total = list.items.fold<int>(
                  0,
                  (sum, payout) =>
                      sum +
                      (payout.status.v == 'paid' ? payout.amount.v ?? 0 : 0),
                );
                return ListView(
                  children: [
                    ListTile(
                      dense: true,
                      title: Text('Paid, ${list.items.length} payouts'),
                      trailing: Text(
                        stripeManagerFormatAmount(
                          total,
                          list.items.first.currency.v,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    for (var payout in list.items)
                      ListTile(
                        title: Text(
                          stripeManagerFormatAmount(
                            payout.amount.v,
                            payout.currency.v,
                          ),
                        ),
                        subtitle: Text(
                          '${payout.status.v ?? '?'} · arrival '
                          '${stripeManagerFormatDay(payout.arrivalDate.v)}'
                          '${(payout.automatic.v ?? true) ? '' : ' · manual'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => StripeManagerPayoutScreen(
                              service: service,
                              payout: payout,
                            ),
                          ),
                        ),
                      ),
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

/// A payout and the balance transactions it paid out.
class StripeManagerPayoutScreen extends StatelessWidget {
  /// The service.
  final StripeManagerService service;

  /// The payout.
  final StripeApiPayout payout;

  /// The [payout] of [service].
  const StripeManagerPayoutScreen({
    super.key,
    required this.service,
    required this.payout,
  });

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payout',
      body: StripeManagerFutureView<StripeManagerList<StripeApiBalanceTransaction>>(
        load: () => service.listBalanceTransactions(payoutId: payout.id.v),
        builder: (context, list, reload) {
          var transactions = list.items
              .where(
                (transaction) =>
                    transaction.type.v != stripeBalanceTransactionTypePayout,
              )
              .toList();
          return ListView(
            children: [
              StripeManagerInfoTile(
                label: 'Amount',
                value: stripeManagerFormatAmount(
                  payout.amount.v,
                  payout.currency.v,
                ),
              ),
              StripeManagerInfoTile(
                label: 'Arrival',
                value: stripeManagerFormatDay(payout.arrivalDate.v),
              ),
              StripeManagerInfoTile(label: 'Status', value: payout.status.v),
              StripeManagerInfoTile(
                label: 'Id',
                value: payout.id.v,
                copy: true,
              ),
              StripeManagerSectionTitle(
                'What it holds (${transactions.length})',
              ),
              for (var transaction in transactions)
                ListTile(
                  dense: true,
                  title: Text(
                    '${transaction.type.v}  '
                    '${transaction.description.v ?? ''}',
                  ),
                  subtitle: Text(
                    '${stripeManagerFormatDateTime(transaction.created.v)}'
                    ' · fee ${stripeManagerFormatAmount(transaction.fee.v, transaction.currency.v)}'
                    ' · ${transaction.source.v ?? ''}',
                  ),
                  trailing: Text(
                    stripeManagerFormatAmount(
                      transaction.net.v,
                      transaction.currency.v,
                    ),
                  ),
                ),
              if (list.truncated)
                const ListTile(title: Text('More transactions exist')),
            ],
          );
        },
      ),
    );
  }
}
