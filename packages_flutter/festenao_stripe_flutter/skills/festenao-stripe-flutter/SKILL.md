---
name: festenao-stripe-flutter
description: >-
  Use when a Flutter app (web included) needs a Stripe back office screen:
  StripeManagerClientStore (sdb, builtInClients, addClient, deleteClient,
  selectClient, current, clients), StripeManagerClient (keyHint, isLive,
  isRestricted), StripeManagerScreen / goToStripeManager (serviceFactory),
  StripeManagerService (getPeriodStats, listProducts, createProduct,
  getSales, listCharges, refundCharge, listPaymentLinks, listPayouts),
  stripeManagerSalesCsv, StripeManagerPeriod from
  package:festenao_stripe_flutter/festenao_stripe_flutter.dart.
---

# Stripe back office (festenao_stripe_flutter)

## Guidelines

* Dependency (git only, not on pub.dev):

  ```yaml
  dependencies:
    festenao_stripe_flutter:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_stripe_flutter
  ```

* Store: `StripeManagerClientStore(factory: sdbFactory, dbName: ...,
  builtInClients: [...])`, `await store.ready()` (the screen does it). The
  user clients (name + key) and the current client id are kept in the sdb
  database; built-in clients are given by the app at each start, never
  stored, never deletable. Without a saved choice the first test client is
  current, never a live one.
* Built-in keys must not reach a release build: build them under
  `if (kDebugMode)` only (the compiler drops the code and its literals), and
  check the build output for them.
* Entry: `goToStripeManager(context, store: store)` (a `Navigator.push`, works
  under any router) or `StripeManagerScreen(store: store)` as a page. Keep it
  behind the app's admin check.
* Tests: `serviceFactory: (client) => StripeManagerService(client: client,
  httpClient: MockClient(...), baseUri: Uri.parse('http://localhost:1/v1'))`;
  the store on `newSdbFactoryMemory()`. In a widget test the progress
  indicators animate forever: pump frames (no `pumpAndSettle`), and complete
  the sdb futures with `tester.runAsync` ticks.
* Pure helpers for scripts and tests: `stripeManagerComputePeriodStats`,
  `stripeManagerComputeSales`, `stripeManagerSalesCsv`,
  `stripeManagerReadAll` (pages of 100 up to `stripeManagerMaxPages`).
