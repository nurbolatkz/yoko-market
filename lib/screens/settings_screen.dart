import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../services/legal_settings_api.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  LegalUrls? _legal;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadLegal();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.version} (сборка ${info.buildNumber})');
  }

  Future<void> _loadLegal() async {
    try {
      final urls = await LegalSettingsApi().getLegalUrls();
      if (!mounted) return;
      setState(() => _legal = urls);
    } catch (_) {
      // Legal section stays hidden on network error — non-critical
    }
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      _showLinkError();
      return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) _showLinkError();
    } catch (_) {
      if (mounted) _showLinkError();
    }
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть ссылку')),
    );
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ctx.read<OrdersProvider>().clearOrders();
              ctx.read<AddressProvider>().clear();
              ctx.read<AuthProvider>().logout();
              Navigator.pop(ctx);
              // Return to profile which will rebuild to guest view
              Navigator.of(context).pop();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    final legal = _legal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Настройки',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Legal section ─────────────────────────────────────────────────
          if (legal != null && legal.hasAny) ...[
            _SectionHeader('Правовая информация'),
            const SizedBox(height: 8),
            if (legal.privacyUrl.isNotEmpty)
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Политика конфиденциальности',
                onTap: () => _openUrl(legal.privacyUrl),
              ),
            if (legal.privacyUrl.isNotEmpty && legal.termsUrl.isNotEmpty)
              const SizedBox(height: 8),
            if (legal.termsUrl.isNotEmpty)
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Условия использования',
                onTap: () => _openUrl(legal.termsUrl),
              ),
            const SizedBox(height: 20),
          ],

          // ── About section ─────────────────────────────────────────────────
          _SectionHeader('О приложении'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Версия',
            trailing: _version.isEmpty
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                : Text(
                    _version,
                    style: const TextStyle(
                      color: AppColors.navyMuted,
                      fontSize: 13,
                    ),
                  ),
          ),

          // ── Account section ───────────────────────────────────────────────
          if (isAuthenticated) ...[
            const SizedBox(height: 20),
            _SectionHeader('Аккаунт'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Выйти',
              titleColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              showChevron: false,
              onTap: _confirmLogout,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.navyMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Settings tile ──────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.titleColor,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final Color? titleColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final effectiveTitleColor = titleColor ?? AppColors.navy;
    final effectiveIconColor = iconColor ?? AppColors.navyMuted;
    final tappable = onTap != null;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.cardBorder,
      child: InkWell(
        borderRadius: AppRadii.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: effectiveIconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: effectiveTitleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (tappable && showChevron) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.navyMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
