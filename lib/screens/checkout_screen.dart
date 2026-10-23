import 'dart:math' show Random, max;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/checkout_estimate.dart';
import '../models/user_address.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/market_provider.dart';
import '../services/checkout_api.dart';
import '../theme/app_theme.dart';
import 'delivery_info_screen.dart';
import 'order_confirmation_screen.dart';
import 'support_screen.dart';
import 'yocoin_screen.dart';

// Private sentinels used only for control-flow inside _onPlaceOrder.
class _SessionExpiredError {}

class _StockChangedError {
  const _StockChangedError(this.detail);
  final String detail;
}

// Result returned from the address bottom sheet.
class _AddrResult {
  const _AddrResult({
    required this.cityCode,
    required this.cityName,
    required this.street,
    required this.house,
    required this.aptOffice,
    required this.comment,
  });
  final String cityCode;
  final String cityName;
  final String street;
  final String house;
  final String aptOffice;
  final String comment;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = CheckoutApi();

  // ── Pre-launch gate ──────────────────────────────────────────────────────────

  bool _ordersBlocked = false;

  // ── Estimate state ───────────────────────────────────────────────────────────

  int _requestVersion = 0;
  CheckoutEstimate? _estimate;
  bool _loading = true;
  bool _placing = false;
  String? _error;
  String? _stockError;

  // One UUID per checkout attempt. Kept across 401/timeout retries.
  String? _idempotencyKey;

  // ── Bonus state ──────────────────────────────────────────────────────────────

  bool _useBonus = false;

  int get _bonusBalance =>
      context.read<AuthProvider>().user?.bonusBalance ?? 0;

  void _onToggleBonus(bool value) {
    setState(() {
      _useBonus = value;
      _estimate = null;
      // Changing bonus_used alters the idempotency hash — reset so a new key
      // is generated if the user proceeds to place the order.
      _idempotencyKey = null;
    });
    _runEstimate();
  }

  // ── Address state ────────────────────────────────────────────────────────────

  String _cityCode = '';
  String _cityName = '';
  String _street = '';
  String _house = '';
  String _aptOffice = '';
  String _comment = '';

  List<BranchCity> _cities = const [];
  bool _citiesLoading = false;
  String? _citiesError;

  // Assembled single-line address passed to API.
  String get _assembledAddress {
    final parts = <String>[];
    if (_cityName.isNotEmpty) parts.add('г. $_cityName');
    if (_street.isNotEmpty) parts.add(_street);
    if (_house.isNotEmpty) parts.add(_house);
    if (_aptOffice.isNotEmpty) parts.add(_aptOffice);
    if (_comment.isNotEmpty) parts.add(_comment);
    return parts.join(', ');
  }

  // ── Checkout gate ─────────────────────────────────────────────────────────────

  // Only allow checkout when:
  //   • A fresh estimate exists
  //   • Delivery is confirmed free (explicit whitelist, server mirrors this guard)
  //   • An address has been provided
  bool get _canPlace {
    final est = _estimate;
    if (est == null) return false;
    if (_assembledAddress.isEmpty) return false;
    return est.delivery.isFree && est.orderTotal != null;
  }

  static String _newUuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Pre-fill from saved default address if available; fall back to legacy profile field.
    final savedDefault = context.read<AddressProvider>().defaultAddress;
    if (savedDefault != null) {
      _cityCode = savedDefault.cityCode;
      _cityName = savedDefault.cityName;
      _street = savedDefault.street;
      _house = savedDefault.house;
      _aptOffice = savedDefault.aptOffice;
      _comment = savedDefault.comment;
    } else {
      _street = context.read<AuthProvider>().user?.address ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final enabled = await _api.getOrdersEnabled();
        if (!mounted) return;
        if (!enabled) {
          setState(() {
            _ordersBlocked = true;
            _loading = false;
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _error = 'Не удалось загрузить настройки. Проверьте подключение.';
          _loading = false;
        });
        return;
      }
      _loadCities();
      _runEstimate();
    });
  }

  // ── Data loading ──────────────────────────────────────────────────────────────

  Future<void> _loadCities() async {
    if (_citiesLoading) return;
    setState(() {
      _citiesLoading = true;
      _citiesError = null;
    });
    try {
      final cities = await _api.getCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _citiesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _citiesLoading = false;
        _citiesError = 'Не удалось загрузить города';
      });
    }
  }

  Future<void> _runEstimate() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
      _stockError = null;
    });

    try {
      final token = await context.read<AuthProvider>().getAccessToken();
      if (!mounted || version != _requestVersion) return;

      if (token == null) {
        setState(() {
          _loading = false;
          _error = 'Сессия истекла. Войдите снова.';
        });
        return;
      }

      final items = context.read<MarketProvider>().cartItems;
      final addr = _assembledAddress;
      final result = await _api.estimate(
        token: token,
        items: items,
        address: addr.isEmpty ? null : addr,
        bonusUsed: _useBonus ? _bonusBalance : 0,
      );

      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _estimate = result;
      });
    } on DioException catch (e) {
      if (!mounted || version != _requestVersion) return;
      final detail = _detail(e);
      setState(() {
        _loading = false;
        if (_isStockError(detail)) {
          _stockError = detail;
        } else {
          _error = (e.response?.statusCode ?? 0) == 401
              ? 'Сессия истекла. Войдите снова.'
              : 'Не удалось загрузить расчёт. Проверьте подключение.';
        }
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить расчёт. Проверьте подключение.';
      });
    }
  }

  static String? _detail(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['detail'] as String?;
    return null;
  }

  static bool _isStockError(String? d) => const {
        'product_not_found',
        'insufficient_stock',
        'product_inactive',
        'no_valid_products',
      }.contains(d);

  // ── Address sheet ─────────────────────────────────────────────────────────────

  Future<void> _onOpenAddressSheet() async {
    final result = await showModalBottomSheet<_AddrResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressSheet(
        cities: _cities,
        citiesLoading: _citiesLoading,
        citiesError: _citiesError,
        onRetryLoadCities: _loadCities,
        cityCode: _cityCode,
        cityName: _cityName,
        street: _street,
        house: _house,
        aptOffice: _aptOffice,
        comment: _comment,
      ),
    );
    if (!mounted || result == null) return;

    // Clear stale estimate so _canPlace is false until the new estimate arrives.
    setState(() {
      _cityCode = result.cityCode;
      _cityName = result.cityName;
      _street = result.street;
      _house = result.house;
      _aptOffice = result.aptOffice;
      _comment = result.comment;
      _estimate = null;
    });
    _runEstimate();
  }

  Future<void> _onSelectSavedAddress() async {
    final addresses = context.read<AddressProvider>().addresses;
    if (addresses.isEmpty) return;
    final selected = await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedAddressPicker(addresses: addresses),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _cityCode = selected.cityCode;
      _cityName = selected.cityName;
      _street = selected.street;
      _house = selected.house;
      _aptOffice = selected.aptOffice;
      _comment = selected.comment;
      _estimate = null;
    });
    _runEstimate();
  }

  // ── Place order ───────────────────────────────────────────────────────────────

  Future<void> _onPlaceOrder() async {
    if (_placing || !_canPlace) return;

    _idempotencyKey ??= _newUuid();
    final idemKey = _idempotencyKey!;

    setState(() => _placing = true);

    final authProvider = context.read<AuthProvider>();
    final marketProvider = context.read<MarketProvider>();
    final items = marketProvider.cartItems;
    final snapshot =
        items.map((ci) => MapEntry(ci.product.id, ci.quantity)).toList();
    // Snapshot address and bonus at place-time so retries are idempotent.
    // Using bonusApplied (server-confirmed) rather than _bonusBalance ensures
    // the request hash is stable across retries even if the balance changed.
    final address = _assembledAddress;
    final confirmedTotal = _estimate!.orderTotal;
    final bonusToApply = _estimate!.bonusApplied;

    try {
      String? token = await authProvider.getAccessToken();
      if (!mounted) return;

      PlaceOrderResult result;
      try {
        if (token == null) {
          token = await authProvider.ensureFreshToken();
          if (!mounted) return;
          if (token == null) throw _SessionExpiredError();
        }
        result = await _api.placeOrder(
          token: token,
          items: items,
          address: address,
          idempotencyKey: idemKey,
          confirmedTotal: confirmedTotal,
          bonusUsed: bonusToApply,
        );
      } on DioException catch (e) {
        if (!mounted) return;
        if ((e.response?.statusCode ?? 0) == 401) {
          final fresh = await authProvider.ensureFreshToken();
          if (!mounted) return;
          if (fresh == null) throw _SessionExpiredError();
          result = await _api.placeOrder(
            token: fresh,
            items: items,
            address: address,
            idempotencyKey: idemKey,
            confirmedTotal: confirmedTotal,
            bonusUsed: bonusToApply,
          );
        } else if ((e.response?.statusCode ?? 0) == 503 &&
            (e.response?.data as Map?)?['detail'] == 'b2c_orders_unavailable') {
          if (mounted) setState(() => _ordersBlocked = true);
          return;
        } else if (_isStockError(_detail(e))) {
          throw _StockChangedError(_detail(e) ?? '');
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      marketProvider.clearOrderedItems(snapshot);
      _idempotencyKey = null;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            result: result,
            expectedTotal: confirmedTotal,
          ),
        ),
      );
    } on PendingOrderException catch (p) {
      if (!mounted) return;
      _showPendingOrderDialog(p.orderNumber, p.total);
    } on PriceChangedException catch (p) {
      if (!mounted) return;
      setState(() {
        _estimate = p.newEstimate;
        _idempotencyKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Цены изменились — проверьте новый расчёт и повторите.'),
          duration: Duration(seconds: 4),
        ),
      );
    } on _StockChangedError catch (e) {
      if (!mounted) return;
      await _runEstimate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stockMessage(e.detail))),
      );
    } on _SessionExpiredError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла. Войдите снова.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final isNetwork = e.response == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNetwork
              ? 'Нет подключения. Корзина сохранена — повторите попытку.'
              : 'Не удалось оформить заказ. Попробуйте позже.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не удалось оформить заказ. Попробуйте позже.')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  static String _stockMessage(String detail) => switch (detail) {
        'insufficient_stock' =>
          'Остатки изменились — уменьшите количество в корзине.',
        'product_inactive' => 'Один из товаров больше не продаётся.',
        'product_not_found' => 'Один из товаров был снят с продажи.',
        _ => 'Состав заказа изменился — проверьте корзину.',
      };

  void _showPendingOrderDialog(String orderNumber, int total) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Уже есть активный заказ'),
        content: Text(
          'Заказ № $orderNumber на сумму ${_fmt(total)} ₸ ожидает обработки.\n\n'
          'Новый заказ можно оформить после его завершения.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final phone = auth.user?.phone ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Оформление заказа',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _buildBody(context, phone),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String phone) {
    if (_ordersBlocked) return _buildOrdersBlockedView(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_stockError != null) {
      return _StockErrorView(
        errorCode: _stockError!,
        onBack: () => Navigator.pop(context),
      );
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _runEstimate);
    }

    final est = _estimate!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              _SectionLabel(title: 'Товары (${est.items.length})'),
              const SizedBox(height: 8),
              _ItemsCard(items: est.items),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const _SectionLabel(title: 'Доставка'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DeliveryInfoScreen()),
                    ),
                    child: const Text(
                      'Условия →',
                      style: TextStyle(
                        color: AppColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DeliveryCard(
                phone: phone,
                address: _assembledAddress,
                onEditAddress: _onOpenAddressSheet,
                citiesLoading: _citiesLoading,
                onSelectSaved: context.read<AddressProvider>().addresses.isNotEmpty
                    ? _onSelectSavedAddress
                    : null,
              ),
              const SizedBox(height: 20),
              const _SectionLabel(title: 'YoCoin'),
              const SizedBox(height: 8),
              _YoCoinCard(
                bonusBalance: _bonusBalance,
                useBonus: _useBonus,
                onToggle: _onToggleBonus,
                bonusApplied: est.bonusApplied,
              ),
              const SizedBox(height: 20),
              const _SectionLabel(title: 'Расчёт'),
              const SizedBox(height: 8),
              _SummaryCard(estimate: est),
            ],
          ),
        ),
        _BottomBar(
          estimate: est,
          onPlaceOrder: _onPlaceOrder,
          placing: _placing,
          canPlace: _canPlace,
        ),
      ],
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navyMuted,
            letterSpacing: .3,
          ),
    );
  }
}

// ── Items card ─────────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});
  final List<EstimateItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _ItemRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final EstimateItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.qty} × ${_fmt(item.serverPrice)} ₸',
                style: const TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fmt(item.lineTotal)} ₸',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Delivery card ──────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.phone,
    required this.address,
    required this.onEditAddress,
    required this.citiesLoading,
    this.onSelectSaved,
  });

  final String phone;
  final String address;
  final VoidCallback onEditAddress;
  final bool citiesLoading;
  final VoidCallback? onSelectSaved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Phone — read-only
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: AppColors.navyMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  phone,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Address — tappable, opens structured form
          InkWell(
            onTap: onEditAddress,
            borderRadius: onSelectSaved != null
                ? BorderRadius.zero
                : const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.navyMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      address.isEmpty ? 'Укажите адрес доставки' : address,
                      style: TextStyle(
                        color: address.isEmpty
                            ? AppColors.navyMuted
                            : AppColors.navy,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (citiesLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.purple),
                    )
                  else
                    Text(
                      address.isEmpty ? 'Добавить' : 'Изменить',
                      style: const TextStyle(
                        color: AppColors.purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onSelectSaved != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            InkWell(
              onTap: onSelectSaved,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.bookmarks_outlined, size: 16, color: AppColors.purple),
                    SizedBox(width: 8),
                    Text(
                      'Выбрать из сохранённых',
                      style: TextStyle(
                        color: AppColors.purple,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Address bottom sheet ───────────────────────────────────────────────────────

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({
    required this.cities,
    required this.citiesLoading,
    required this.citiesError,
    required this.onRetryLoadCities,
    required this.cityCode,
    required this.cityName,
    required this.street,
    required this.house,
    required this.aptOffice,
    required this.comment,
  });

  final List<BranchCity> cities;
  final bool citiesLoading;
  final String? citiesError;
  final VoidCallback onRetryLoadCities;
  final String cityCode;
  final String cityName;
  final String street;
  final String house;
  final String aptOffice;
  final String comment;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late String _cityCode;
  late String _cityName;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _houseCtrl;
  late final TextEditingController _aptCtrl;
  late final TextEditingController _commentCtrl;
  String? _cityError;

  @override
  void initState() {
    super.initState();
    _cityCode = widget.cityCode;
    _cityName = widget.cityName;
    _streetCtrl = TextEditingController(text: widget.street);
    _houseCtrl = TextEditingController(text: widget.house);
    _aptCtrl = TextEditingController(text: widget.aptOffice);
    _commentCtrl = TextEditingController(text: widget.comment);
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    _houseCtrl.dispose();
    _aptCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    // City is required when the list loaded successfully and has entries.
    if (_cityCode.isEmpty && widget.cities.isNotEmpty) {
      setState(() => _cityError = 'Выберите город');
      return;
    }
    Navigator.pop(
      context,
      _AddrResult(
        cityCode: _cityCode,
        cityName: _cityName,
        street: _streetCtrl.text.trim(),
        house: _houseCtrl.text.trim(),
        aptOffice: _aptCtrl.text.trim(),
        comment: _commentCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, max(20.0, bottomInset + 20.0)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Адрес доставки',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              // ── City picker ───────────────────────────────────────────────
              if (widget.citiesLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (widget.citiesError != null) ...[
                _InfoBanner(
                  icon: Icons.wifi_off_rounded,
                  text: widget.citiesError!,
                  action: TextButton(
                    onPressed: widget.onRetryLoadCities,
                    child: const Text('Повторить'),
                  ),
                ),
              ] else if (widget.cities.isEmpty) ...[
                _InfoBanner(
                  icon: Icons.location_off_outlined,
                  text: 'Доставка временно недоступна в вашем регионе',
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _cityCode.isEmpty ? null : _cityCode,
                  hint: const Text('Выберите город'),
                  decoration: InputDecoration(
                    labelText: 'Город',
                    errorText: _cityError,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  items: widget.cities
                      .map((c) => DropdownMenuItem(
                            value: c.code,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (code) {
                    if (code == null) return;
                    final city =
                        widget.cities.firstWhere((c) => c.code == code);
                    setState(() {
                      _cityCode = code;
                      _cityName = city.name;
                      _cityError = null;
                    });
                  },
                ),
              ],

              const SizedBox(height: 12),

              // ── Street ────────────────────────────────────────────────────
              _AddressField(
                controller: _streetCtrl,
                label: 'Улица',
                hint: 'пр. Абая',
              ),
              const SizedBox(height: 12),

              // ── House + Apt ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _AddressField(
                      controller: _houseCtrl,
                      label: 'Дом',
                      hint: '10',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AddressField(
                      controller: _aptCtrl,
                      label: 'Квартира / офис',
                      hint: '5',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Comment ───────────────────────────────────────────────────
              _AddressField(
                controller: _commentCtrl,
                label: 'Комментарий',
                hint: 'Код домофона, этаж, ориентир',
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Сохранить адрес',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.label,
    required this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.navyMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: AppColors.navyMuted, fontSize: 13),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

// ── Summary breakdown card ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.estimate});
  final CheckoutEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        estimate.promoDiscount > 0 || estimate.bonusApplied > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Товары',
            value: '${_fmt(estimate.subtotal)} ₸',
          ),
          if (estimate.promoDiscount > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Промокод',
              value: '−${_fmt(estimate.promoDiscount)} ₸',
              valueColor: const Color(0xFF23804A),
            ),
          ],
          if (estimate.bonusApplied > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Бонусы',
              value: '−${_fmt(estimate.bonusApplied)} ₸',
              valueColor: const Color(0xFF23804A),
            ),
          ],
          if (hasDiscount) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Итого товаров',
              value: '${_fmt(estimate.itemsTotal)} ₸',
              labelWeight: FontWeight.w600,
              valueWeight: FontWeight.w600,
            ),
          ],
          const SizedBox(height: 8),
          _DeliveryRow(delivery: estimate.delivery),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.navy,
    this.labelWeight = FontWeight.w500,
    this.valueWeight = FontWeight.w600,
  });

  final String label;
  final String value;
  final Color valueColor;
  final FontWeight labelWeight;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                color: AppColors.navyMuted,
                fontSize: 14,
                fontWeight: labelWeight),
          ),
        ),
        Text(
          value,
          style: TextStyle(
              color: valueColor, fontSize: 14, fontWeight: valueWeight),
        ),
      ],
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.delivery});
  final EstimateDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            'Доставка',
            style: TextStyle(
                color: AppColors.navyMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ),
        if (delivery.isFree)
          const Text(
            'Бесплатно',
            style: TextStyle(
              color: Color(0xFF23804A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Flexible(
            child: Text(
              delivery.shortfall > 0
                  ? 'Ещё ${_fmt(delivery.shortfall)} ₸\nдо бесплатной доставки'
                  : 'Стоимость доставки\nпока не рассчитана',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.estimate,
    required this.onPlaceOrder,
    required this.placing,
    required this.canPlace,
  });

  final CheckoutEstimate estimate;
  final VoidCallback onPlaceOrder;
  final bool placing;
  final bool canPlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delivery = estimate.delivery;
    final totalKnown = estimate.orderTotal != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalKnown ? 'Итого к оплате' : 'Итого без учёта доставки',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.navyMuted),
                  ),
                ),
                Text(
                  '${_fmt(totalKnown ? estimate.orderTotal! : estimate.itemsTotal)} ₸',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            if (!totalKnown && delivery.shortfall > 0) ...[
              const SizedBox(height: 3),
              Text(
                'Добавьте ещё ${_fmt(delivery.shortfall)} ₸ до бесплатной доставки',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.navyMuted),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('checkout-place-order'),
              onPressed: canPlace && !placing ? onPlaceOrder : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: placing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Оформить заказ',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ── Orders blocked view ────────────────────────────────────────────────────────

Widget _buildOrdersBlockedView(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 56, color: AppColors.purple),
          const SizedBox(height: 16),
          Text(
            'Приём заказов скоро откроется',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мы готовим сервис к запуску.\nСледите за обновлениями.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.navyMuted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
            icon: const Icon(Icons.headset_mic_outlined, size: 18),
            label: const Text('Поддержка'),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Error views ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: AppColors.purple),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockErrorView extends StatelessWidget {
  const _StockErrorView({required this.errorCode, required this.onBack});
  final String errorCode;
  final VoidCallback onBack;

  String get _message => switch (errorCode) {
        'insufficient_stock' =>
          'Недостаточно товара на складе.\nУменьшите количество в корзине.',
        'product_inactive' =>
          'Один из товаров больше не продаётся.\nУдалите его из корзины.',
        'product_not_found' =>
          'Один из товаров не найден.\nВозможно, он был снят с продажи.',
        _ => 'В корзине нет действующих товаров.',
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 52,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Вернуться в корзину'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── YoCoin card ───────────────────────────────────────────────────────────────

class _YoCoinCard extends StatelessWidget {
  const _YoCoinCard({
    required this.bonusBalance,
    required this.useBonus,
    required this.onToggle,
    required this.bonusApplied,
  });

  final int bonusBalance;
  final bool useBonus;
  final ValueChanged<bool> onToggle;
  final int bonusApplied;

  @override
  Widget build(BuildContext context) {
    final hasBalance = bonusBalance > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(
          color: useBonus && hasBalance ? AppColors.purple : AppColors.border,
          width: useBonus && hasBalance ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + label + balance chip
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, hasBalance ? 0 : 10),
            child: Row(
              children: [
                const Icon(Icons.toll_rounded,
                    size: 18, color: AppColors.purple),
                const SizedBox(width: 8),
                const Text(
                  'YoCoin',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasBalance
                        ? AppColors.purpleSoft
                        : const Color(0xFFF2F2F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_fmt(bonusBalance)} ₸',
                    style: TextStyle(
                      color: hasBalance
                          ? AppColors.purple
                          : AppColors.navyMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!hasBalance) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Бонусов пока нет — зарабатывайте за каждый заказ',
                style: TextStyle(color: AppColors.navyMuted, fontSize: 13),
              ),
            ),
          ] else ...[
            SwitchListTile(
              value: useBonus,
              onChanged: onToggle,
              title: const Text(
                'Использовать YoCoin',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: useBonus && bonusApplied > 0
                  ? Text(
                      'Спишется ${_fmt(bonusApplied)} ₸',
                      style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    )
                  : null,
              activeThumbColor: AppColors.purple,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            ),
          ],

          const Divider(height: 1, color: AppColors.border),
          // "Как это работает" link
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YoCoinScreen()),
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(16, 9, 16, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.purple),
                  SizedBox(width: 4),
                  Text(
                    'Как это работает',
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saved address picker ───────────────────────────────────────────────────────

class _SavedAddressPicker extends StatelessWidget {
  const _SavedAddressPicker({required this.addresses});
  final List<UserAddress> addresses;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Сохранённые адреса',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
              itemBuilder: (_, i) {
                final addr = addresses[i];
                final text = addr.assembledText;
                return ListTile(
                  leading: Icon(
                    addr.isDefault
                        ? Icons.location_on_rounded
                        : Icons.location_on_outlined,
                    color: addr.isDefault
                        ? AppColors.purple
                        : AppColors.navyMuted,
                    size: 20,
                  ),
                  title: Text(
                    text.isEmpty ? 'Адрес не заполнен' : text,
                    style: TextStyle(
                      fontSize: 14,
                      color: text.isEmpty ? AppColors.navyMuted : AppColors.navy,
                    ),
                  ),
                  trailing: addr.isDefault
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purpleSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Основной',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, addr),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Formatting ─────────────────────────────────────────────────────────────────

String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
