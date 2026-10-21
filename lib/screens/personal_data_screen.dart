import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  late final TextEditingController _nameCtrl;
  final _formKey = GlobalKey<FormState>();

  bool _saving = false;
  String? _saveError;
  late String _savedName; // tracks what's persisted so we can detect dirty state

  @override
  void initState() {
    super.initState();
    final name = context.read<AuthProvider>().user?.fullName ?? '';
    _savedName = name;
    _nameCtrl = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty => _nameCtrl.text.trim() != _savedName;

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final result = await showDialog<_LeaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Сохранить изменения перед выходом?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.discard),
            child: const Text('Не сохранять'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.save),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (result == _LeaveAction.save) {
      final ok = await _save();
      return ok;
    }
    return result == _LeaveAction.discard;
  }

  Future<bool> _save() async {
    if (_saving) return false;
    if (!(_formKey.currentState?.validate() ?? false)) return false;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await context
          .read<AuthProvider>()
          .patchUser(fullName: _nameCtrl.text.trim());

      if (!mounted) return true;
      _savedName = _nameCtrl.text.trim();
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Данные сохранены'),
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    } on DioException catch (e) {
      if (!mounted) return false;
      final detail = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail'] as String? ?? ''
          : '';
      setState(() {
        _saving = false;
        _saveError = _mapError(e.response?.statusCode, detail);
      });
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _saveError = 'Не удалось сохранить. Проверьте подключение.';
      });
      return false;
    }
  }

  static String _mapError(int? code, String detail) {
    if (code == 401) return 'Сессия истекла. Войдите снова.';
    if (code == 422 || detail.contains('invalid')) return 'Проверьте введённые данные.';
    return 'Не удалось сохранить. Попробуйте позже.';
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.select<AuthProvider, String>(
      (a) => a.user?.phone ?? '',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (allow && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Личные данные',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListenableBuilder(
                      listenable: _nameCtrl,
                      builder: (_, _) => _isDirty
                          ? TextButton(
                              onPressed: _save,
                              child: const Text(
                                'Сохранить',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _SectionLabel('Имя'),
              const SizedBox(height: 8),
              _NameField(controller: _nameCtrl, enabled: !_saving),
              if (_saveError != null) ...[
                const SizedBox(height: 10),
                _ErrorBanner(message: _saveError!),
              ],
              const SizedBox(height: 24),
              _SectionLabel('Телефон'),
              const SizedBox(height: 8),
              _PhoneField(phone: phone),
              const SizedBox(height: 8),
              const Text(
                'Телефон привязан к аккаунту и не может быть изменён.',
                style: TextStyle(
                  color: AppColors.navyMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              ListenableBuilder(
                listenable: _nameCtrl,
                builder: (_, _) => FilledButton(
                  onPressed: (_isDirty && !_saving) ? _save : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.navyMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Name field ────────────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Введите ваше имя',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: AppColors.navyMuted),
                  onPressed: enabled ? controller.clear : null,
                )
              : const SizedBox.shrink(),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Введите имя';
        if (v.trim().length < 2) return 'Имя должно содержать не менее 2 символов';
        return null;
      },
    );
  }
}

// ── Phone field (read-only) ───────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatPhone(phone),
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: AppColors.navyMuted),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFD32F2F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

enum _LeaveAction { save, discard }

String _formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('7')) {
    final n = digits.substring(1);
    return '+7 ${n.substring(0, 3)} ${n.substring(3, 6)} '
        '${n.substring(6, 8)} ${n.substring(8, 10)}';
  }
  return phone;
}
