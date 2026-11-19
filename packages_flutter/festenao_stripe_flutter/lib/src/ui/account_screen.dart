import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../service.dart';
import 'widgets.dart';

/// The text of a payout [schedule]: `monthly on day 1, 7 days delay`.
String stripeManagerScheduleText(StripeApiPayoutSchedule schedule) {
  var interval = schedule.interval.v ?? '?';
  var text = switch (interval) {
    'weekly' => 'weekly on ${schedule.weeklyAnchor.v ?? '?'}',
    'monthly' => 'monthly on day ${schedule.monthlyAnchor.v ?? '?'}',
    'manual' => 'manual (triggered from the dashboard)',
    _ => interval,
  };
  if (schedule.delayDays.v case var days?) {
    text = '$text, $days days delay';
  }
  return text;
}

/// The account of the key.
class StripeManagerAccountScreen extends StatelessWidget {
  /// The service.
  final StripeManagerService service;

  /// The account of [service].
  const StripeManagerAccountScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    var client = service.client;
    return StripeManagerScaffold(
      client: client,
      title: 'Account',
      body: StripeManagerFutureView<StripeApiAccount?>(
        load: service.getAccountOrNull,
        builder: (context, account, reload) {
          return ListView(
            children: [
              StripeManagerInfoTile(label: 'Client', value: client.name),
              StripeManagerInfoTile(label: 'Key', value: client.keyHint),
              StripeManagerInfoTile(
                label: 'Mode',
                value: client.isLive ? 'Live' : 'Test',
              ),
              if (account == null)
                const ListTile(
                  title: Text(
                    'The account cannot be read with this key (a '
                    'restricted key without the account read access).',
                  ),
                )
              else ...[
                StripeManagerInfoTile(
                  label: 'Account id',
                  value: account.id.v,
                  copy: true,
                ),
                StripeManagerInfoTile(
                  label: 'Name',
                  value:
                      account.settings.v?.dashboard.v?.displayName.v ??
                      account.businessProfile.v?.name.v,
                ),
                StripeManagerInfoTile(label: 'Email', value: account.email.v),
                StripeManagerInfoTile(
                  label: 'Country',
                  value: account.country.v,
                ),
                StripeManagerInfoTile(
                  label: 'Default currency',
                  value: account.defaultCurrency.v,
                ),
                StripeManagerInfoTile(
                  label: 'Charges enabled',
                  value: '${account.chargesEnabled.v ?? '?'}',
                ),
                StripeManagerInfoTile(
                  label: 'Payouts enabled',
                  value: '${account.payoutsEnabled.v ?? '?'}',
                ),
                StripeManagerInfoTile(
                  label: 'Payout schedule',
                  value: switch (account.settings.v?.payouts.v?.schedule.v) {
                    var schedule? => stripeManagerScheduleText(schedule),
                    null => null,
                  },
                ),
                StripeManagerInfoTile(
                  label: 'Statement descriptor',
                  value: account.settings.v?.payouts.v?.statementDescriptor.v,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
