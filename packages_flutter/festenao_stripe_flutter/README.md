# festenao_stripe_flutter

A small Stripe back office for Flutter, web included (the Stripe API
answers browser calls): pick a Stripe key ("client"), then look at and act on
its account.

- Clients: secret (`sk_`) or restricted (`rk_`) keys, test or live, kept on
  the device in a sdb database (IndexedDB on the web); the app can give
  built-in ones (debug keys, never stored, not deletable). A key is checked
  (balance call) before it is kept and never shown in full.
- Dashboard: balance, payments, gross, fees, refunds, net and payouts of a
  period (from the balance transactions), payout schedule, last payouts.
- Products: active or archived, create (with an optional one time price),
  rename, prices (add, default, deactivate), archive, restore, delete.
- Sales: paid Checkout Sessions (Payment Links included) of a period, by
  product (sales, units, amount), one product only, csv to the clipboard.
- Payments: charges, details, refunds.
- Payment links: active or not, items, completed payments, deactivate.
- Payouts: list and the transactions each one paid out.
- Account: id, name, country, payouts schedule (when the key may read it).

Every write asks for a confirmation; on a live key the user types `LIVE`
and every screen shows a red banner.

```dart
import 'package:festenao_stripe_flutter/festenao_stripe_flutter.dart';

final store = StripeManagerClientStore(factory: sdbFactory);
await goToStripeManager(context, store: store);
```

The client calls use `tekartik_stripe_api` (git,
`alextekartik/http_apis.dart`, `packages/stripe`).

A secret key in a browser or a device is as exposed as the device: prefer a
restricted key with the read accesses needed (and write accesses only for the
actions used), and keep the screens behind an admin check.
