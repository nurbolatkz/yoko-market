import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../models/checkout_estimate.dart';
import '../models/user_address.dart';
import '../theme/app_theme.dart';

/// Result returned by [AddressFormSheet].
class AddressFormResult {
  const AddressFormResult({
    required this.cityCode,
    required this.cityName,
    required this.street,
    required this.house,
    required this.aptOffice,
    required this.comment,
    required this.isDefault,
  });

  final String cityCode;
  final String cityName;
  final String street;
  final String house;
  final String aptOffice;
  final String comment;
  final bool isDefault;

  UserAddress toAddress({String id = '', bool? forceDefault}) => UserAddress(
        id: id,
        cityCode: cityCode,
        cityName: cityName,
        street: street,
        house: house,
        aptOffice: aptOffice,
        comment: comment,
        isDefault: forceDefault ?? isDefault,
      );
}

/// Opens a scrollable bottom sheet form for adding / editing a delivery address.
///
/// Returns [AddressFormResult] when the user taps Save, or null on dismiss.
Future<AddressFormResult?> showAddressFormSheet(
  BuildContext context, {
  required List<BranchCity> cities,
  required bool citiesLoading,
  String? citiesError,
  VoidCallback? onRetryLoadCities,
  UserAddress? initial,
  bool showDefaultToggle = true,
}) {
  return showModalBottomSheet<AddressFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddressFormSheet(
      cities: cities,
      citiesLoading: citiesLoading,
      citiesError: citiesError,
      onRetryLoadCities: onRetryLoadCities,
      initial: initial,
      showDefaultToggle: showDefaultToggle,
    ),
  );
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({
    required this.cities,
    required this.citiesLoading,
    required this.citiesError,
    required this.onRetryLoadCities,
    required this.initial,
    required this.showDefaultToggle,
  });

  final List<BranchCity> cities;
  final bool citiesLoading;
  final String? citiesError;
  final VoidCallback? onRetryLoadCities;
  final UserAddress? initial;
  final bool showDefaultToggle;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  late String _cityCode;
  late String _cityName;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _houseCtrl;
  late final TextEditingController _aptCtrl;
  late final TextEditingController _commentCtrl;
  late bool _isDefault;
  String? _cityError;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _cityCode = init?.cityCode ?? '';
    _cityName = init?.cityName ?? '';
    _streetCtrl = TextEditingController(text: init?.street ?? '');
    _houseCtrl = TextEditingController(text: init?.house ?? '');
    _aptCtrl = TextEditingController(text: init?.aptOffice ?? '');
    _commentCtrl = TextEditingController(text: init?.comment ?? '');
    _isDefault = init?.isDefault ?? false;
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
    if (_cityCode.isEmpty && widget.cities.isNotEmpty) {
      setState(() => _cityError = 'Выберите город');
      return;
    }
    Navigator.pop(
      context,
      AddressFormResult(
        cityCode: _cityCode,
        cityName: _cityName,
        street: _streetCtrl.text.trim(),
        house: _houseCtrl.text.trim(),
        aptOffice: _aptCtrl.text.trim(),
        comment: _commentCtrl.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initial != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 0, 16, max(20.0, bottomInset + 20.0)),
      child: SingleChildScrollView(
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
            Text(
              isEditing ? 'Редактировать адрес' : 'Новый адрес',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // ── City picker ───────────────────────────────────────────────────
            if (widget.citiesLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (widget.citiesError != null) ...[
              _FormInfoBanner(
                icon: Icons.wifi_off_rounded,
                text: widget.citiesError!,
                action: widget.onRetryLoadCities != null
                    ? TextButton(
                        onPressed: widget.onRetryLoadCities,
                        child: const Text('Повторить'),
                      )
                    : null,
              ),
            ] else if (widget.cities.isEmpty) ...[
              const _FormInfoBanner(
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: widget.cities
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (code) {
                  if (code == null) return;
                  final city = widget.cities.firstWhere((c) => c.code == code);
                  setState(() {
                    _cityCode = code;
                    _cityName = city.name;
                    _cityError = null;
                  });
                },
              ),
            ],

            const SizedBox(height: 12),
            _Field(controller: _streetCtrl, label: 'Улица', hint: 'пр. Абая'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(controller: _houseCtrl, label: 'Дом', hint: '10'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                      controller: _aptCtrl,
                      label: 'Кв. / офис',
                      hint: '5'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _commentCtrl,
              label: 'Комментарий',
              hint: 'Код домофона, этаж, ориентир',
            ),

            if (widget.showDefaultToggle) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text(
                  'Адрес по умолчанию',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.purple,
              ),
            ],

            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Сохранить адрес', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

class _FormInfoBanner extends StatelessWidget {
  const _FormInfoBanner({required this.icon, required this.text, this.action});

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
            child: Text(text,
                style: const TextStyle(color: AppColors.navyMuted, fontSize: 13)),
          ),
          ?action,
        ],
      ),
    );
  }
}
