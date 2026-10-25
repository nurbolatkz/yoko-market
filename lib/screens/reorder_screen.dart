import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/skeleton.dart';
import 'cart_screen.dart';
import 'product_catalog_screen.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key, required this.order});

  final OrderSummary order;

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

// ── Per-item state ─────────────────────────────────────────────────────────────

class _ReorderItem {
  _ReorderItem({required this.orderItem, this.product})
      : isSelected = product != null && product.inStock;

  final OrderItem orderItem;
  final Product? product;
  bool isSelected;

  bool get isAvailable => product != null && product!.inStock;

  // Quantity to add: original qty capped by current stock.
  int get addQty =>
      isAvailable ? orderItem.qty.clamp(0, product!.stockQuantity) : 0;

  bool get priceChanged =>
      isAvailable && product!.price.round() != orderItem.unitPrice;

  // Human-readable size label (empty string when size is ONE / not set).
  String get sizeLabel {
    final pkg = product?.packageInfo ?? '';
    return pkg.isNotEmpty ? pkg : '';
  }
}

// ── Screen state ───────────────────────────────────────────────────────────────

class _ReorderScreenState extends State<ReorderScreen> {
  List<_ReorderItem>? _items;
  Object? _error;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final market = context.read<MarketProvider>();
      final results = await Future.wait(
        widget.order.items.map((item) async {
          final pid = item.productId;
          if (pid == null || pid.isEmpty) {
            return _ReorderItem(orderItem: item);
          }
          try {
            final result = await market.getProductById(pid);
            return _ReorderItem(orderItem: item, product: result.product);
          } catch (_) {
            return _ReorderItem(orderItem: item);
          }
        }),
      );
      if (mounted) setState(() => _items = results);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  // ── Derived state ────────────────────────────────────────────────────────────

  int get _selectedCount =>
      _items?.where((i) => i.isSelected).length ?? 0;

  bool get _hasUnavailable =>
      _items?.any((i) => !i.isAvailable) ?? false;

  bool get _allUnavailable =>
      (_items?.isNotEmpty ?? false) && _items!.every((i) => !i.isAvailable);

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _addToCart() async {
    final selected =
        _items!.where((i) => i.isSelected && i.isAvailable).toList();
    if (selected.isEmpty) return;

    setState(() => _isAdding = true);
    final market = context.read<MarketProvider>();
    for (final ri in selected) {
      if (ri.addQty > 0) {
        market.addToCartWithQty(ri.product!, ri.addQty);
      }
    }
    setState(() => _isAdding = false);
    if (!mounted) return;

    final n = selected.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добавлено $n ${_itemWord(n)} в корзину'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CartScreen(onGoToCatalog: () => Navigator.pop(context)),
            ),
          ),
        ),
      ),
    );
    Navigator.pop(context);
  }

  void _openReplacement() {
    final unavailable =
        _items?.where((i) => !i.isAvailable).toList() ?? [];
    final category = unavailable
        .map((i) => i.product?.category ?? '')
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');

    final market = context.read<MarketProvider>();
    if (category.isNotEmpty) {
      market.setSelectedCategory(category);
      market.loadProducts();
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductCatalogScreen()),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Повторить заказ',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Заказ №${widget.order.orderNumber}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.navyMuted,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: ErrorState(
          onRetry: _load,
          onBack: () => Navigator.pop(context),
        ),
      );
    }
    if (_items == null) return _buildSkeleton();
    if (_allUnavailable) return _buildAllUnavailable();
    return _buildLoaded();
  }

  Widget _buildLoaded() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              const Text(
                'Проверьте товары',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final item in _items!) ...[
                _buildItemCard(item),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              const Text(
                'Цены и наличие могут измениться. '
                'В корзину добавим только доступные товары.',
                style: TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildItemCard(_ReorderItem ri) {
    final nameLabel = ri.sizeLabel.isNotEmpty
        ? '${ri.orderItem.name}, ${ri.sizeLabel}'
        : ri.orderItem.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        ri.isAvailable ? AppColors.navy : AppColors.navyMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                if (ri.isAvailable) ...[
                  if (ri.priceChanged)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 2,
                      children: [
                        Text(
                          'Было ${formatMoney(ri.orderItem.unitPrice)}',
                          style: const TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const Text(
                          '→',
                          style: TextStyle(
                            color: AppColors.navyMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'сейчас ${formatMoney(ri.product!.price.round())}',
                          style: const TextStyle(
                            color: AppColors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Текущая цена · ${formatMoney(ri.product!.price.round())}',
                      style: const TextStyle(
                        color: AppColors.navyMuted,
                        fontSize: 12,
                      ),
                    ),
                ] else
                  const Text(
                    'Нет в наличии',
                    style: TextStyle(
                      color: AppColors.navyMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (ri.isAvailable)
            GestureDetector(
              onTap: () => setState(() => ri.isSelected = !ri.isSelected),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ri.isSelected ? AppColors.purple : Colors.transparent,
                  border: Border.all(
                    color:
                        ri.isSelected ? AppColors.purple : AppColors.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ri.isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.remove_rounded,
                color: AppColors.navyMuted,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final n = _selectedCount;
    final buttonLabel =
        n == 0 ? 'Выберите товары' : 'Добавить $n ${_itemWord(n)} в корзину';

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: buttonLabel,
            variant:
                n == 0 ? AppButtonVariant.disabled : AppButtonVariant.primary,
            loading: _isAdding,
            fullWidth: true,
            onPressed: n > 0 ? _addToCart : null,
          ),
          if (_hasUnavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Выбрать замену',
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: _openReplacement,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Skeleton.rect(width: 160, height: 20),
        const SizedBox(height: 16),
        for (int i = 0; i < widget.order.items.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardBorder,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.rect(height: 14, radius: 4),
                      const SizedBox(height: 6),
                      Skeleton.rect(width: 120, height: 12, radius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Skeleton.rect(width: 28, height: 28, radius: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAllUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3l, vertical: AppSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: AppColors.navyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Товары из этого заказа\nсейчас недоступны',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            AppButton(
              label: 'Выбрать замену',
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: _openReplacement,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _itemWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 19) return 'товаров';
  if (mod10 == 1) return 'товар';
  if (mod10 >= 2 && mod10 <= 4) return 'товара';
  return 'товаров';
}
