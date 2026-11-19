/// A small Stripe back office for Flutter (web included): the clients (keys)
/// kept on the device in a sdb database, a dashboard, products and prices,
/// sales by product with a csv export, payments and refunds, payment links,
/// payouts and the account.
///
/// ```dart
/// final store = StripeManagerClientStore(factory: sdbFactory);
/// await goToStripeManager(context, store: store);
/// ```
library;

export 'src/client.dart';
export 'src/client_store.dart';
export 'src/format.dart';
export 'src/paged.dart';
export 'src/service.dart';
export 'src/ui/account_screen.dart'
    show StripeManagerAccountScreen, stripeManagerScheduleText;
export 'src/ui/clients_screen.dart' show StripeManagerClientsScreen;
export 'src/ui/dashboard_screen.dart' show StripeManagerDashboardScreen;
export 'src/ui/home_screen.dart'
    show StripeManagerScreen, StripeManagerServiceFactory, goToStripeManager;
export 'src/ui/paged_list_view.dart' show StripeManagerPagedListView;
export 'src/ui/payment_links_screen.dart'
    show StripeManagerPaymentLinksScreen, StripeManagerPaymentLinkScreen;
export 'src/ui/payments_screen.dart'
    show StripeManagerPaymentsScreen, StripeManagerChargeScreen;
export 'src/ui/payouts_screen.dart'
    show StripeManagerPayoutsScreen, StripeManagerPayoutScreen;
export 'src/ui/products_screen.dart'
    show StripeManagerProductsScreen, StripeManagerProductScreen;
export 'src/ui/sales_screen.dart'
    show StripeManagerSalesScreen, showStripeManagerSession;
export 'src/ui/widgets.dart'
    show
        StripeManagerModeChip,
        StripeManagerLiveBanner,
        stripeManagerConfirm,
        stripeManagerParseCents;
