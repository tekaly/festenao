import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'widgets.dart';

/// The charges of a period.
class StripeManagerPaymentsScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The payments of [service].
  const StripeManagerPaymentsScreen({super.key, required this.service});

  @override
  State<StripeManagerPaymentsScreen> createState() =>
      _StripeManagerPaymentsScreenState();
}

class _StripeManagerPaymentsScreenState
    extends State<StripeManagerPaymentsScreen> {
  var _period = StripeManagerPeriod.days30;
  var _reloadCount = 0;

  StripeManagerService get service => widget.service;

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payments',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: Text('Charges')),
                StripeManagerPeriodSelector(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
              ],
            ),
          ),
          Expanded(
            child: StripeManagerFutureView<StripeManagerList<StripeApiCharge>>(
              reloadKey: (_period, _reloadCount),
              load: () =>
                  service.listCharges(startSeconds: _period.startSeconds()),
              builder: (context, list, reload) {
                if (list.items.isEmpty) {
                  return const Center(child: Text('No payment in the period'));
                }
                return ListView(
                  children: [
                    for (var charge in list.items)
                      ListTile(
                        leading: Icon(_statusIcon(charge)),
                        title: Text(
                          '${stripeManagerFormatAmount(charge.amount.v, charge.currency.v)}'
                          '  ${charge.billingDetails.v?.name.v ?? charge.billingDetails.v?.email.v ?? charge.receiptEmail.v ?? ''}',
                        ),
                        subtitle: Text(
                          '${stripeManagerFormatDateTime(charge.created.v)} · '
                          '${_statusText(charge)}'
                          '${charge.description.v == null ? '' : '\n${charge.description.v}'}',
                        ),
                        isThreeLine: charge.description.v != null,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => StripeManagerChargeScreen(
                                service: service,
                                chargeId: charge.id.v!,
                              ),
                            ),
                          );
                          setState(() => _reloadCount++);
                        },
                      ),
                    if (list.truncated)
                      const ListTile(
                        title: Text('More payments exist: shorten the period'),
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

IconData _statusIcon(StripeApiCharge charge) {
  if (charge.refunded.v ?? false) {
    return Icons.undo;
  }
  return switch (charge.status.v) {
    'succeeded' => Icons.check_circle,
    'failed' => Icons.error,
    _ => Icons.hourglass_empty,
  };
}

String _statusText(StripeApiCharge charge) {
  var refunded = charge.amountRefunded.v ?? 0;
  if (charge.refunded.v ?? false) {
    return 'refunded';
  }
  if (refunded > 0) {
    return '${charge.status.v}, '
        '${stripeManagerFormatAmount(refunded, charge.currency.v)} refunded';
  }
  return charge.status.v ?? '?';
}

/// A charge and its refund.
class StripeManagerChargeScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The charge id.
  final String chargeId;

  /// The charge [chargeId] of [service].
  const StripeManagerChargeScreen({
    super.key,
    required this.service,
    required this.chargeId,
  });

  @override
  State<StripeManagerChargeScreen> createState() =>
      _StripeManagerChargeScreenState();
}

class _StripeManagerChargeScreenState extends State<StripeManagerChargeScreen> {
  var _reloadCount = 0;

  StripeManagerService get service => widget.service;

  Future<void> _refund(StripeApiCharge charge) async {
    var remaining = (charge.amount.v ?? 0) - (charge.amountRefunded.v ?? 0);
    var amountText = stripeManagerFormatAmount(remaining, charge.currency.v);
    var text = await stripeManagerAskText(
      context,
      title: 'Refund',
      label: 'Amount in € (at most $amountText)',
      initialValue: stripeManagerFormatCsvAmount(remaining),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (text) {
        var cents = stripeManagerParseCents(text);
        if (cents == null || cents > remaining) {
          return 'An amount above 0 up to $amountText';
        }
        return null;
      },
    );
    if (text == null || !mounted) {
      return;
    }
    var cents = stripeManagerParseCents(text)!;
    var who =
        charge.billingDetails.v?.email.v ??
        charge.receiptEmail.v ??
        'the payer';
    if (!await stripeManagerConfirm(
      context,
      client: service.client,
      title: 'Refund',
      message:
          'Refund ${stripeManagerFormatAmount(cents, charge.currency.v)} to '
          '$who? This cannot be undone.',
      action: 'Refund',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (await stripeManagerRun(context, () async {
      await service.refundCharge(
        charge.id.v!,
        cents: cents == remaining ? null : cents,
      );
    }, success: 'Refund sent')) {
      if (mounted) {
        setState(() => _reloadCount++);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payment',
      body: StripeManagerFutureView<StripeApiCharge>(
        reloadKey: _reloadCount,
        load: () => service.api.getCharge(widget.chargeId),
        builder: (context, charge, reload) {
          var billing = charge.billingDetails.v;
          var remaining =
              (charge.amount.v ?? 0) - (charge.amountRefunded.v ?? 0);
          return ListView(
            children: [
              StripeManagerInfoTile(
                label: 'Amount',
                value: stripeManagerFormatAmount(
                  charge.amount.v,
                  charge.currency.v,
                ),
              ),
              StripeManagerInfoTile(
                label: 'Status',
                value: _statusText(charge),
              ),
              StripeManagerInfoTile(
                label: 'Date',
                value: stripeManagerFormatDateTime(charge.created.v),
              ),
              StripeManagerInfoTile(label: 'Name', value: billing?.name.v),
              StripeManagerInfoTile(
                label: 'Email',
                value: billing?.email.v ?? charge.receiptEmail.v,
                copy: true,
              ),
              StripeManagerInfoTile(
                label: 'Description',
                value: charge.description.v,
              ),
              if (charge.failureMessage.v case var failure?)
                StripeManagerInfoTile(label: 'Failure', value: failure),
              if (charge.metadata.v case var metadata? when metadata.isNotEmpty)
                StripeManagerInfoTile(
                  label: 'Metadata',
                  value: metadata.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                ),
              StripeManagerInfoTile(
                label: 'Charge',
                value: charge.id.v,
                copy: true,
              ),
              StripeManagerInfoTile(
                label: 'Payment intent',
                value: charge.paymentIntent.v,
                copy: true,
              ),
              StripeManagerInfoTile(
                label: 'Receipt',
                value: charge.receiptUrl.v,
                copy: true,
              ),
              if ((charge.paid.v ?? false) && remaining > 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.undo),
                    label: const Text('Refund'),
                    onPressed: () => _refund(charge),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
