import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'paged_list_view.dart';
import 'sales_screen.dart';
import 'widgets.dart';

/// The Payment Links, active or not, read page by page (kept while the
/// client stays selected, the refresh action reads them again).
class StripeManagerPaymentLinksScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The links of [service].
  const StripeManagerPaymentLinksScreen({super.key, required this.service});

  @override
  State<StripeManagerPaymentLinksScreen> createState() =>
      _StripeManagerPaymentLinksScreenState();
}

class _StripeManagerPaymentLinksScreenState
    extends State<StripeManagerPaymentLinksScreen> {
  var _active = true;

  StripeManagerService get service => widget.service;

  Future<void> _open(StripeApiPaymentLink link) async {
    var changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StripeManagerPaymentLinkScreen(service: service, paymentLink: link),
      ),
    );
    if (changed ?? false) {
      // Moved from a tab to the other.
      service.pagedPaymentLinks(active: true).refresh().ignore();
      service.pagedPaymentLinks(active: false).refresh().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = service.pagedPaymentLinks(active: _active);
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payment links',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: list.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Active')),
                ButtonSegment(value: false, label: Text('Inactive')),
              ],
              selected: {_active},
              onSelectionChanged: (selection) =>
                  setState(() => _active = selection.first),
            ),
          ),
          Expanded(
            child: StripeManagerPagedListView<StripeApiPaymentLink>(
              key: ValueKey(_active),
              list: list,
              emptyText: 'No payment link',
              itemsName: 'links',
              itemBuilder: (context, link) {
                var summary = StripeManagerPaymentLinkSummary(link);
                var amount = summary.amount;
                return ListTile(
                  title: Text(summary.title ?? link.url.v ?? link.id.v ?? '?'),
                  subtitle: Text(
                    [
                      [
                        if (summary.date case var date?)
                          stripeManagerFormatDateTime(date),
                        ?summary.paidText,
                        if (link.metadata.v case var metadata?
                            when metadata.isNotEmpty)
                          metadata.entries
                              .map((e) => '${e.key}: ${e.value}')
                              .join(', '),
                      ].join(' · '),
                      link.id.v ?? '',
                    ].join('\n'),
                  ),
                  trailing: amount == null
                      ? null
                      : Text(
                          stripeManagerFormatAmount(amount, summary.currency),
                        ),
                  onTap: () => _open(link),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkData {
  final List<StripeApiLineItem> items;
  final List<StripeApiCheckoutSession> sessions;

  _LinkData(this.items, this.sessions);
}

/// A Payment Link: its items, its completed payments, deactivate it.
class StripeManagerPaymentLinkScreen extends StatelessWidget {
  /// The service.
  final StripeManagerService service;

  /// The link.
  final StripeApiPaymentLink paymentLink;

  /// The [paymentLink] of [service].
  const StripeManagerPaymentLinkScreen({
    super.key,
    required this.service,
    required this.paymentLink,
  });

  Future<_LinkData> _load() async {
    var id = paymentLink.id.v!;
    // The line items read with the list, else read now.
    var expandedItems = paymentLink.lineItemList.v?.data.v;
    var results = await Future.wait<Object>([
      if (expandedItems == null) service.listPaymentLinkLineItems(id),
      service.listPaymentLinkSessions(id),
    ]);
    return _LinkData(
      expandedItems ?? results.first as List<StripeApiLineItem>,
      results.last as List<StripeApiCheckoutSession>,
    );
  }

  @override
  Widget build(BuildContext context) {
    var active = paymentLink.active.v ?? true;
    var summary = StripeManagerPaymentLinkSummary(paymentLink);
    var limit = paymentLink.restrictions.v?.completedSessions.v?.limit.v;
    return StripeManagerScaffold(
      client: service.client,
      title: 'Payment link',
      body: StripeManagerFutureView<_LinkData>(
        load: _load,
        builder: (context, data, reload) {
          var date = StripeManagerPaymentLinkSummary(
            paymentLink,
            items: data.items,
          ).date;
          return ListView(
            children: [
              StripeManagerInfoTile(
                label: 'Url',
                value: paymentLink.url.v,
                copy: true,
              ),
              StripeManagerInfoTile(
                label: 'Id',
                value: paymentLink.id.v,
                copy: true,
              ),
              if (date != null)
                StripeManagerInfoTile(
                  label:
                      'Date (of its newest price, Stripe keeps no link date)',
                  value: stripeManagerFormatDateTime(date),
                ),
              StripeManagerInfoTile(
                label: 'Status',
                value: [
                  if (active) 'active' else 'inactive',
                  if (limit != null) 'at most $limit payment(s)',
                  ?summary.paidText,
                ].join(', '),
              ),
              if (paymentLink.metadata.v case var metadata?
                  when metadata.isNotEmpty)
                StripeManagerInfoTile(
                  label: 'Metadata',
                  value: metadata.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                ),
              const StripeManagerSectionTitle('Items'),
              for (var item in data.items)
                ListTile(
                  dense: true,
                  title: Text(
                    '${item.quantity.v ?? 1} × ${item.description.v ?? '?'}',
                  ),
                  trailing: Text(
                    stripeManagerFormatAmount(
                      item.amountTotal.v,
                      item.currency.v,
                    ),
                  ),
                ),
              StripeManagerSectionTitle(
                'Completed payments (${data.sessions.length})',
              ),
              for (var session in data.sessions)
                ListTile(
                  dense: true,
                  title: Text(
                    '${stripeManagerFormatDateTime(session.created.v)}  '
                    '${session.customerDetails.v?.email.v ?? ''}',
                  ),
                  subtitle: Text(session.paymentStatus.v ?? ''),
                  trailing: Text(
                    stripeManagerFormatAmount(
                      session.amountTotal.v,
                      session.currency.v,
                    ),
                  ),
                  onTap: () => showStripeManagerSession(
                    context,
                    session,
                    const {},
                    service: service,
                  ),
                ),
              if (active)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.link_off),
                    label: const Text('Deactivate'),
                    onPressed: () async {
                      if (!await stripeManagerConfirm(
                        context,
                        client: service.client,
                        title: 'Deactivate link',
                        message:
                            'Deactivate this link? Nobody can pay with it '
                            'anymore.',
                        action: 'Deactivate',
                      )) {
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      var navigator = Navigator.of(context);
                      if (await stripeManagerRun(context, () async {
                        await service.setPaymentLinkActive(
                          paymentLink.id.v!,
                          false,
                        );
                      }, success: 'Link deactivated')) {
                        // Changed: the list reads its tabs again.
                        navigator.pop(true);
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
