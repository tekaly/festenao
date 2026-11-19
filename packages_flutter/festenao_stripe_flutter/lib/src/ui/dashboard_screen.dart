import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'account_screen.dart';
import 'widgets.dart';

class _DashboardData {
  final StripeApiBalance balance;
  final StripeManagerPeriodStats stats;
  final StripeApiAccount? account;
  final List<StripeApiPayout> payouts;

  _DashboardData({
    required this.balance,
    required this.stats,
    required this.account,
    required this.payouts,
  });
}

/// The balance, the period stats, the payout schedule and the last payouts.
class StripeManagerDashboardScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The dashboard of [service].
  const StripeManagerDashboardScreen({super.key, required this.service});

  @override
  State<StripeManagerDashboardScreen> createState() =>
      _StripeManagerDashboardScreenState();
}

class _StripeManagerDashboardScreenState
    extends State<StripeManagerDashboardScreen> {
  var _period = StripeManagerPeriod.days30;

  StripeManagerService get service => widget.service;

  Future<_DashboardData> _load() async {
    var results = await Future.wait<Object?>([
      service.getBalance(),
      service.getPeriodStats(_period),
      service.getAccountOrNull(),
      service.api.listPayouts(StripeApiPayoutListOptions()..limit.v = 5),
    ]);
    return _DashboardData(
      balance: results[0] as StripeApiBalance,
      stats: results[1] as StripeManagerPeriodStats,
      account: results[2] as StripeApiAccount?,
      payouts:
          (results[3] as StripeApiPayoutList).data.v ??
          const <StripeApiPayout>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Dashboard',
      body: StripeManagerFutureView<_DashboardData>(
        reloadKey: _period,
        load: _load,
        builder: (context, data, reload) {
          var balance = data.balance;
          var stats = data.stats;
          var schedule = data.account?.settings.v?.payouts.v?.schedule.v;
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              children: [
                const StripeManagerSectionTitle('Balance'),
                for (var amount
                    in balance.available.v ?? const <StripeApiBalanceAmount>[])
                  StripeManagerInfoTile(
                    label: 'Available',
                    value: stripeManagerFormatAmount(
                      amount.amount.v,
                      amount.currency.v,
                    ),
                  ),
                for (var amount
                    in balance.pending.v ?? const <StripeApiBalanceAmount>[])
                  StripeManagerInfoTile(
                    label: 'Pending',
                    value: stripeManagerFormatAmount(
                      amount.amount.v,
                      amount.currency.v,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Period',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StripeManagerPeriodSelector(
                        period: _period,
                        onChanged: (period) => setState(() => _period = period),
                      ),
                    ],
                  ),
                ),
                if (stats.byCurrency.isEmpty)
                  const ListTile(title: Text('No transaction in the period')),
                for (var currencyStats in stats.byCurrency.values)
                  _CurrencyStatsCard(stats: currencyStats),
                if (stats.truncated)
                  ListTile(
                    title: Text(
                      'Only the last ${stats.transactionCount} transactions '
                      'were read',
                    ),
                  ),
                const StripeManagerSectionTitle('Payouts'),
                StripeManagerInfoTile(
                  label: 'Schedule',
                  value: schedule == null
                      ? 'Not readable with this key'
                      : stripeManagerScheduleText(schedule),
                ),
                for (var payout in data.payouts)
                  ListTile(
                    dense: true,
                    title: Text(
                      stripeManagerFormatAmount(
                        payout.amount.v,
                        payout.currency.v,
                      ),
                    ),
                    subtitle: Text(
                      '${payout.status.v ?? '?'}, arrival '
                      '${stripeManagerFormatDay(payout.arrivalDate.v)}'
                      '${(payout.automatic.v ?? true) ? '' : ', manual'}',
                    ),
                  ),
                if (data.payouts.isEmpty)
                  const ListTile(dense: true, title: Text('No payout yet')),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CurrencyStatsCard extends StatelessWidget {
  final StripeManagerCurrencyStats stats;

  const _CurrencyStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    String amount(int cents) =>
        stripeManagerFormatAmount(cents, stats.currency);
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row('Payments', '${stats.paymentCount}'),
            row('Gross', amount(stats.gross)),
            row('Refunds (${stats.refundCount})', amount(-stats.refunded)),
            row('Stripe fees', amount(-stats.fees)),
            const Divider(),
            row('Net', amount(stats.net), bold: true),
            row('Paid out', amount(stats.paidOut)),
          ],
        ),
      ),
    );
  }
}
