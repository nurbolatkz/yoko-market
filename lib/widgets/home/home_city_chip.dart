import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkout_estimate.dart';
import '../../providers/auth_provider.dart';
import '../../services/checkout_api.dart';
import '../../theme/app_theme.dart';
import '../city_picker_sheet.dart';

/// Signed-in user's city in the Home header; tapping changes it.
///
/// The city is the user's profile city (`GET/PATCH /profile` → `city`); the
/// backend derives the branch — and with it checkout prices and stock — from
/// it. Guests have no stored city (they pick one at checkout), so the chip is
/// hidden for them rather than showing a made-up value.
class HomeCityChip extends StatefulWidget {
  const HomeCityChip({super.key, this.api});

  final CheckoutApi? api;

  @override
  State<HomeCityChip> createState() => _HomeCityChipState();
}

class _HomeCityChipState extends State<HomeCityChip> {
  late final CheckoutApi _api = widget.api ?? CheckoutApi();
  List<BranchCity>? _cities;
  bool _busy = false;

  Future<List<BranchCity>?> _loadCities() async {
    if (_cities != null) return _cities;
    try {
      final cities = await _api.getCities();
      if (mounted) setState(() => _cities = cities);
      return cities;
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.read<AuthProvider>().isAuthenticated) _loadCities();
  }

  Future<void> _pick() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final cities = await _loadCities();
    if (!mounted) return;
    if (cities == null || cities.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить города')),
      );
      return;
    }
    final chosen = await showCityPickerSheet(
      context,
      cities: cities,
      selectedCode: auth.user?.city,
    );
    if (!mounted || chosen == null || chosen.code == auth.user?.city) return;
    setState(() => _busy = true);
    try {
      await auth.patchUser(cityCode: chosen.code);
      messenger.showSnackBar(
        SnackBar(content: Text('Город изменён: ${chosen.name}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось сменить город')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    final code = auth.user?.city;
    final name = code == null
        ? 'Выберите город'
        : (_cities
                  ?.where((c) => c.code == code)
                  .map((c) => c.name)
                  .firstOrNull ??
              'Город');
    return Semantics(
      button: true,
      label: 'Город доставки: $name. Изменить',
      excludeSemantics: true,
      child: InkWell(
        onTap: _pick,
        borderRadius: AppRadii.chipBorder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.brandRed,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _busy
                    ? const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandRed,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.navyMuted,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
