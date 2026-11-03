import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/checkout_estimate.dart';
import '../../providers/auth_provider.dart';
import '../../services/checkout_api.dart';
import '../../services/referral_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  final _checkoutApi = CheckoutApi();
  final _referralApi = ReferralApi();

  List<BranchCity> _cities = [];
  BranchCity? _selectedCity;
  bool _loadingCities = true;
  bool _saving = false;
  String? _error;
  String? _referralError;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await _checkoutApi.getCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final referralCode = _referralController.text.trim().toUpperCase();
    final auth = context.read<AuthProvider>();
    setState(() { _saving = true; _error = null; _referralError = null; });
    try {
      await auth.patchUser(
        fullName: name.isEmpty ? null : name,
        cityCode: _selectedCity?.code,
      );
      // Apply referral code if entered
      if (referralCode.isNotEmpty) {
        try {
          final token = await auth.getAccessToken();
          if (!mounted) return;
          if (token != null) {
            final bonus = await _referralApi.activateReferral(token, referralCode);
            if (mounted && bonus > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Реферальный код принят! +$bonus бонусов начислено'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } on DioException catch (e) {
          final detail = (e.response?.data is Map)
              ? e.response!.data['detail'] as String?
              : null;
          if (detail == 'invalid_code') {
            if (mounted) setState(() => _referralError = 'Неверный код. Проверьте и попробуйте снова.');
          }
          // already_referred — silently ignore (might happen on retry)
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Не удалось сохранить. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() => Navigator.of(context).pop();


  void _showCityPicker() {
    if (_cities.isEmpty) return;
    showModalBottomSheet<BranchCity>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text('Выберите город',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.navy)),
          ),
          ..._cities.map((city) => ListTile(
                title: Text(city.name,
                    style: const TextStyle(color: AppColors.navy, fontSize: 15)),
                trailing: _selectedCity?.code == city.code
                    ? const Icon(Icons.check_rounded, color: AppColors.purple)
                    : null,
                onTap: () {
                  setState(() => _selectedCity = city);
                  Navigator.of(context).pop();
                },
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = !_saving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text('Пропустить',
                style: TextStyle(color: AppColors.navyMuted, fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Знакомство',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.navyMuted)),
            const SizedBox(height: 8),
            Text('Как к вам обращаться?',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 32),
            // Name field
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(
                  borderRadius: AppRadii.inputBorder,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputBorder,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputBorder,
                  borderSide: const BorderSide(color: AppColors.purple, width: 2),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            // City picker
            InkWell(
              onTap: _loadingCities ? null : _showCityPicker,
              borderRadius: AppRadii.inputBorder,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Город',
                  border: OutlineInputBorder(borderRadius: AppRadii.inputBorder),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.inputBorder,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  suffixIcon: _loadingCities
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                      : const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.navyMuted),
                ),
                child: Text(
                  _selectedCity?.name ?? '',
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Referral code field (optional)
            TextField(
              controller: _referralController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Реферальный код (необязательно)',
                hintText: 'Например: ABC123',
                border: OutlineInputBorder(borderRadius: AppRadii.inputBorder),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputBorder,
                  borderSide: BorderSide(
                    color: _referralError != null
                        ? AppColors.error
                        : AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputBorder,
                  borderSide: const BorderSide(
                      color: AppColors.purple, width: 2),
                ),
                errorText: _referralError,
                suffixIcon: const Icon(Icons.card_giftcard_rounded,
                    color: AppColors.navyMuted, size: 20),
              ),
              onChanged: (_) {
                if (_referralError != null) {
                  setState(() => _referralError = null);
                }
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Сохранить и продолжить',
              loading: _saving,
              variant: canSave ? AppButtonVariant.primary : AppButtonVariant.disabled,
              onPressed: canSave ? _save : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            const Text(
              'Остальные данные можно добавить позже в Профиле.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.navyMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
