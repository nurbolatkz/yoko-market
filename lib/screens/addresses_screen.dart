import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/checkout_estimate.dart';
import '../models/user_address.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../services/checkout_api.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form_sheet.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _checkoutApi = CheckoutApi();
  List<BranchCity> _cities = const [];
  bool _citiesLoading = false;
  String? _citiesError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCities();
      _ensureAddressesLoaded();
    });
  }

  Future<void> _loadCities() async {
    setState(() {
      _citiesLoading = true;
      _citiesError = null;
    });
    try {
      final cities = await _checkoutApi.getCities();
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

  Future<void> _ensureAddressesLoaded() async {
    final provider = context.read<AddressProvider>();
    if (provider.isLoaded) return;
    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted || token == null) return;
    await provider.load(token);
  }

  Future<void> _reload() async {
    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted || token == null) return;
    await context.read<AddressProvider>().load(token);
  }

  Future<void> _onAdd() async {
    final result = await showAddressFormSheet(
      context,
      cities: _cities,
      citiesLoading: _citiesLoading,
      citiesError: _citiesError,
      onRetryLoadCities: _loadCities,
    );
    if (!mounted || result == null) return;

    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted || token == null) return;

    try {
      await context.read<AddressProvider>().add(
            token,
            result.toAddress(forceDefault: result.isDefault),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить адрес')),
      );
    }
  }

  Future<void> _onEdit(UserAddress addr) async {
    final result = await showAddressFormSheet(
      context,
      cities: _cities,
      citiesLoading: _citiesLoading,
      citiesError: _citiesError,
      onRetryLoadCities: _loadCities,
      initial: addr,
    );
    if (!mounted || result == null) return;

    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted || token == null) return;

    try {
      await context.read<AddressProvider>().update(
            token,
            addr.id,
            result.toAddress(id: addr.id),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить адрес')),
      );
    }
  }

  Future<void> _onSetDefault(UserAddress addr) async {
    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted || token == null) return;
    try {
      await context.read<AddressProvider>().setDefault(token, addr.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить адрес')),
      );
    }
  }

  Future<void> _onDelete(UserAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить адрес?'),
        content: Text(
          addr.assembledText.isEmpty ? 'Этот адрес будет удалён.' : addr.assembledText,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = await context.read<AuthProvider>().getAccessToken();
    if (!mounted || token == null) return;

    try {
      await context.read<AddressProvider>().delete(token, addr.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить адрес')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Мои адреса',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAdd,
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        tooltip: 'Добавить адрес',
        child: const Icon(Icons.add_rounded),
      ),
      body: _Body(
        onEdit: _onEdit,
        onSetDefault: _onSetDefault,
        onDelete: _onDelete,
        onRetry: _reload,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
    required this.onRetry,
  });

  final ValueChanged<UserAddress> onEdit;
  final ValueChanged<UserAddress> onSetDefault;
  final ValueChanged<UserAddress> onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddressProvider>();

    if (provider.loadState == AddressLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.loadState == AddressLoadState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 56, color: AppColors.navyMuted),
              const SizedBox(height: 16),
              Text(
                provider.error ?? 'Ошибка загрузки',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Повторить'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final addresses = provider.addresses;

    if (addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded,
                  size: 64, color: AppColors.navyMuted),
              const SizedBox(height: 16),
              const Text(
                'Нет сохранённых адресов',
                style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Нажмите + чтобы добавить адрес доставки',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.navyMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: addresses.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _AddressTile(
        address: addresses[index],
        onEdit: onEdit,
        onSetDefault: onSetDefault,
        onDelete: onDelete,
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final UserAddress address;
  final ValueChanged<UserAddress> onEdit;
  final ValueChanged<UserAddress> onSetDefault;
  final ValueChanged<UserAddress> onDelete;

  @override
  Widget build(BuildContext context) {
    final assembled = address.assembledText;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.cardBorder,
      child: InkWell(
        borderRadius: AppRadii.cardBorder,
        onTap: address.isDefault ? null : () => onSetDefault(address),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  address.isDefault
                      ? Icons.location_on_rounded
                      : Icons.location_on_outlined,
                  size: 20,
                  color: address.isDefault
                      ? AppColors.purple
                      : AppColors.navyMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (address.isDefault)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purpleSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'По умолчанию',
                          style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    Text(
                      assembled.isEmpty ? 'Адрес не заполнен' : assembled,
                      style: TextStyle(
                        color: assembled.isEmpty
                            ? AppColors.navyMuted
                            : AppColors.navy,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (!address.isDefault) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => onSetDefault(address),
                        child: const Text(
                          'Сделать основным',
                          style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.navyMuted),
                    onPressed: () => onEdit(address),
                    tooltip: 'Редактировать',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.navyMuted),
                    onPressed: () => onDelete(address),
                    tooltip: 'Удалить',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
