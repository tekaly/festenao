import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../format.dart';
import '../service.dart';
import 'sales_screen.dart';
import 'widgets.dart';

/// The products, active or archived.
class StripeManagerProductsScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The products of [service].
  const StripeManagerProductsScreen({super.key, required this.service});

  @override
  State<StripeManagerProductsScreen> createState() =>
      _StripeManagerProductsScreenState();
}

class _StripeManagerProductsScreenState
    extends State<StripeManagerProductsScreen> {
  var _active = true;
  var _reloadCount = 0;

  StripeManagerService get service => widget.service;

  Future<void> _add() async {
    var created = await showDialog<_NewProduct>(
      context: context,
      builder: (_) => const _NewProductDialog(),
    );
    if (created == null || !mounted) {
      return;
    }
    var price = created.cents == null
        ? 'no price'
        : 'price ${stripeManagerFormatAmount(created.cents)}';
    if (!await stripeManagerConfirm(
      context,
      client: service.client,
      title: 'Create product',
      message: 'Create "${created.name}" ($price)?',
      action: 'Create',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    await stripeManagerRun(context, () async {
      await service.createProduct(
        name: created.name,
        description: created.description,
        priceCents: created.cents,
      );
      setState(() {
        _active = true;
        _reloadCount++;
      });
    }, success: 'Product created');
  }

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Products',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a product',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Active')),
                ButtonSegment(value: false, label: Text('Archived')),
              ],
              selected: {_active},
              onSelectionChanged: (selection) =>
                  setState(() => _active = selection.first),
            ),
          ),
          Expanded(
            child: StripeManagerFutureView<List<StripeApiProduct>>(
              reloadKey: (_active, _reloadCount),
              load: () => service.listProducts(active: _active),
              builder: (context, products, reload) {
                if (products.isEmpty) {
                  return Center(
                    child: Text(_active ? 'No product' : 'No archived product'),
                  );
                }
                return ListView(
                  children: [
                    for (var product in products)
                      ListTile(
                        title: Text(product.name.v ?? product.id.v ?? '?'),
                        subtitle: Text(
                          [product.id.v, ?product.description.v].join('\n'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => StripeManagerProductScreen(
                                service: service,
                                productId: product.id.v!,
                              ),
                            ),
                          );
                          reload();
                        },
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

class _NewProduct {
  final String name;
  final String? description;
  final int? cents;

  _NewProduct({required this.name, this.description, this.cents});
}

class _NewProductDialog extends StatefulWidget {
  const _NewProductDialog();

  @override
  State<_NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<_NewProductDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var priceText = _price.text.trim();
    var priceError = priceText.isEmpty
        ? null
        : stripeManagerAmountError(priceText);
    var canCreate = _name.text.trim().isNotEmpty && priceError == null;
    return AlertDialog(
      title: const Text('New product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('stripe_manager_product_name'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
              minLines: 1,
            ),
            TextField(
              key: const ValueKey('stripe_manager_product_price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'One time price in € (optional)',
                errorText: priceError,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canCreate
              ? () => Navigator.of(context).pop(
                  _NewProduct(
                    name: _name.text.trim(),
                    description: _description.text.trim().isEmpty
                        ? null
                        : _description.text.trim(),
                    cents: priceText.isEmpty
                        ? null
                        : stripeManagerParseCents(priceText),
                  ),
                )
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _ProductData {
  final StripeApiProduct product;
  final List<StripeApiPrice> prices;

  _ProductData(this.product, this.prices);
}

/// A product, its prices and the actions on them.
class StripeManagerProductScreen extends StatefulWidget {
  /// The service.
  final StripeManagerService service;

  /// The product id.
  final String productId;

  /// The product [productId] of [service].
  const StripeManagerProductScreen({
    super.key,
    required this.service,
    required this.productId,
  });

  @override
  State<StripeManagerProductScreen> createState() =>
      _StripeManagerProductScreenState();
}

class _StripeManagerProductScreenState
    extends State<StripeManagerProductScreen> {
  var _reloadCount = 0;

  StripeManagerService get service => widget.service;
  String get productId => widget.productId;

  Future<_ProductData> _load() async {
    var results = await Future.wait<Object>([
      service.api.getProduct(productId),
      service.listPrices(productId),
    ]);
    return _ProductData(
      results[0] as StripeApiProduct,
      results[1] as List<StripeApiPrice>,
    );
  }

  void _reload() => setState(() => _reloadCount++);

  Future<void> _write({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() run,
    String? success,
    bool popOnSuccess = false,
  }) async {
    if (!await stripeManagerConfirm(
      context,
      client: service.client,
      title: title,
      message: message,
      action: action,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    var navigator = Navigator.of(context);
    var ok = await stripeManagerRun(context, run, success: success);
    if (ok) {
      if (popOnSuccess) {
        navigator.pop();
      } else if (mounted) {
        _reload();
      }
    }
  }

  Future<void> _edit(StripeApiProduct product) async {
    var name = await stripeManagerAskText(
      context,
      title: 'Product name',
      label: 'Name',
      initialValue: product.name.v,
      validator: (text) => text.trim().isEmpty ? 'A name' : null,
    );
    if (name == null || !mounted) {
      return;
    }
    var description = await stripeManagerAskText(
      context,
      title: 'Product description',
      label: 'Description (empty to keep it)',
      initialValue: product.description.v,
    );
    if (!mounted) {
      return;
    }
    await _write(
      title: 'Update product',
      message: 'Rename to "${name.trim()}"?',
      action: 'Update',
      success: 'Product updated',
      run: () async {
        await service.updateProduct(
          productId,
          name: name.trim(),
          description: (description?.trim().isEmpty ?? true)
              ? null
              : description!.trim(),
        );
      },
    );
  }

  Future<void> _addPrice() async {
    var text = await stripeManagerAskText(
      context,
      title: 'New one time price',
      label: 'Amount in €',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: stripeManagerAmountError,
    );
    if (text == null || !mounted) {
      return;
    }
    var cents = stripeManagerParseCents(text)!;
    await _write(
      title: 'Add price',
      message: 'Add a price of ${stripeManagerFormatAmount(cents)}?',
      action: 'Add',
      success: 'Price added',
      run: () async {
        await service.createPrice(productId: productId, cents: cents);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StripeManagerScaffold(
      client: service.client,
      title: 'Product',
      body: StripeManagerFutureView<_ProductData>(
        reloadKey: _reloadCount,
        load: _load,
        builder: (context, data, reload) {
          var product = data.product;
          var active = product.active.v ?? true;
          var name = product.name.v ?? productId;
          return ListView(
            children: [
              ListTile(
                title: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(active ? 'Active' : 'Archived'),
                trailing: IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(product),
                ),
              ),
              StripeManagerInfoTile(label: 'Id', value: productId, copy: true),
              StripeManagerInfoTile(
                label: 'Description',
                value: product.description.v,
              ),
              StripeManagerInfoTile(
                label: 'Created',
                value: stripeManagerFormatDateTime(product.created.v),
              ),
              if (product.metadata.v case var metadata?
                  when metadata.isNotEmpty)
                StripeManagerInfoTile(
                  label: 'Metadata',
                  value: metadata.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                ),
              const StripeManagerSectionTitle('Prices'),
              if (data.prices.isEmpty)
                const ListTile(dense: true, title: Text('No price')),
              for (var price in data.prices)
                _PriceTile(
                  price: price,
                  isDefault: price.id.v == product.defaultPrice.v,
                  onSetDefault: () => _write(
                    title: 'Default price',
                    message:
                        'Make ${stripeManagerFormatAmount(price.amount.v, price.currency.v)} '
                        'the default price?',
                    action: 'Set',
                    success: 'Default price set',
                    run: () async {
                      await service.setDefaultPrice(productId, price.id.v!);
                    },
                  ),
                  onSetActive: (active) => _write(
                    title: active ? 'Activate price' : 'Deactivate price',
                    message:
                        '${active ? 'Activate' : 'Deactivate'} the price '
                        '${stripeManagerFormatAmount(price.amount.v, price.currency.v)}? '
                        'Payment links using it keep working.',
                    action: active ? 'Activate' : 'Deactivate',
                    success: 'Price updated',
                    run: () async {
                      await service.setPriceActive(price.id.v!, active);
                    },
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add a one time price'),
                onTap: _addPrice,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Sales of this product'),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => StripeManagerSalesScreen(
                      service: service,
                      productId: productId,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(active ? Icons.archive : Icons.unarchive),
                title: Text(active ? 'Archive' : 'Restore'),
                subtitle: Text(
                  active
                      ? 'Hidden from new sales, existing links keep their '
                            'prices'
                      : 'Active again',
                ),
                onTap: () => _write(
                  title: active ? 'Archive product' : 'Restore product',
                  message: '${active ? 'Archive' : 'Restore'} "$name"?',
                  action: active ? 'Archive' : 'Restore',
                  success: active ? 'Product archived' : 'Product restored',
                  run: () async {
                    await service.setProductActive(productId, !active);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Delete'),
                subtitle: const Text(
                  'Only a product without prices can be deleted, archive '
                  'the others',
                ),
                onTap: () => _write(
                  title: 'Delete product',
                  message: 'Delete "$name" for good?',
                  action: 'Delete',
                  success: 'Product deleted',
                  popOnSuccess: true,
                  run: () async {
                    await service.deleteProduct(productId);
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  final StripeApiPrice price;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final ValueChanged<bool> onSetActive;

  const _PriceTile({
    required this.price,
    required this.isDefault,
    required this.onSetDefault,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    var active = price.active.v ?? true;
    var recurring = price.recurring.v;
    return ListTile(
      dense: true,
      leading: Icon(
        isDefault ? Icons.star : Icons.sell,
        color: active ? null : Colors.grey,
      ),
      title: Text(
        '${stripeManagerFormatAmount(price.amount.v, price.currency.v)}'
        '${recurring == null ? '' : ' / ${recurring.intervalCount.v ?? 1} ${recurring.interval.v}'}'
        '${active ? '' : ' (inactive)'}',
      ),
      subtitle: Text([price.id.v, ?price.nickname.v].join(' · ')),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'default':
              onSetDefault();
            case 'active':
              onSetActive(!active);
          }
        },
        itemBuilder: (_) => [
          if (!isDefault && active)
            const PopupMenuItem(value: 'default', child: Text('Make default')),
          PopupMenuItem(
            value: 'active',
            child: Text(active ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}
