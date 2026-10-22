import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import 'support_screen.dart';

class DeliveryInfoScreen extends StatefulWidget {
  const DeliveryInfoScreen({super.key});

  @override
  State<DeliveryInfoScreen> createState() => _DeliveryInfoScreenState();
}

class _DeliveryInfoScreenState extends State<DeliveryInfoScreen> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  _DeliveryInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get<dynamic>('/settings/delivery');
      setState(() {
        _info = _DeliveryInfo.fromJson(resp.data as Map<String, dynamic>);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Ошибка сети';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить данные';
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Доставка и оплата',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final info = _info!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // ── Доставка ──────────────────────────────────────────────────────────
        _SectionHeader('Доставка'),
        const SizedBox(height: 8),
        _InfoCard(
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.purple,
          title: 'Города доставки',
          children: info.cities.isEmpty
              ? [
                  const _InfoRow(
                    text: 'Список городов временно недоступен.',
                  ),
                ]
              : info.cities
                  .map((c) => _InfoRow(text: c.name))
                  .toList(),
        ),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.discount_outlined,
          iconColor: const Color(0xFF23804A),
          title: 'Условия бесплатной доставки',
          children: [
            if (info.freeDeliveryThreshold == 0)
              const _InfoRow(text: 'Доставка бесплатна для всех заказов.')
            else ...[
              _InfoRow(
                text:
                    'Бесплатная доставка при заказе от ${_fmt(info.freeDeliveryThreshold)} ₸.',
              ),
              const _InfoRow(
                text:
                    'Точная стоимость доставки рассчитывается при оформлении заказа — она зависит от адреса и состава корзины.',
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ── Оплата ────────────────────────────────────────────────────────────
        _SectionHeader('Оплата'),
        const SizedBox(height: 8),
        for (final pm in info.paymentMethods) ...[
          if (pm.code == 'kaspi')
            _KaspiCard(url: pm.url, onOpen: () => _openUrl(pm.url))
          else
            _InfoCard(
              icon: Icons.payment_outlined,
              iconColor: AppColors.navy,
              title: pm.name,
              children: const [],
            ),
        ],
        const SizedBox(height: 20),

        // ── Поддержка ─────────────────────────────────────────────────────────
        _SectionHeader('Вопросы'),
        const SizedBox(height: 8),
        _SupportCard(
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          ),
        ),
        const SizedBox(height: 4),
      ],
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

// ── Info card ──────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: AppColors.navyMuted, fontSize: 13),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kaspi Pay card ─────────────────────────────────────────────────────────────

class _KaspiCard extends StatelessWidget {
  const _KaspiCard({required this.url, required this.onOpen});
  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.cardBorder,
      child: InkWell(
        borderRadius: AppRadii.cardBorder,
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardBorder,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5122D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  size: 20,
                  color: Color(0xFFF5122D),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kaspi Pay',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ссылка для оплаты придёт после подтверждения заказа',
                      style: TextStyle(
                        color: AppColors.navyMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppColors.navyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Support card ───────────────────────────────────────────────────────────────

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.cardBorder,
      child: InkWell(
        borderRadius: AppRadii.cardBorder,
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardBorder,
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.headset_mic_outlined,
                  size: 20, color: AppColors.navyMuted),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Поддержка / FAQ',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.navyMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.purple),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

class _DeliveryInfo {
  const _DeliveryInfo({
    required this.freeDeliveryThreshold,
    required this.cities,
    required this.paymentMethods,
  });

  final int freeDeliveryThreshold;
  final List<_City> cities;
  final List<_PaymentMethod> paymentMethods;

  factory _DeliveryInfo.fromJson(Map<String, dynamic> j) => _DeliveryInfo(
        freeDeliveryThreshold:
            (j['free_delivery_threshold'] as num?)?.toInt() ?? 0,
        cities: (j['cities'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(_City.fromJson)
            .toList(),
        paymentMethods:
            (j['payment_methods'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(_PaymentMethod.fromJson)
                .toList(),
      );
}

class _City {
  const _City({required this.code, required this.name});
  final String code;
  final String name;
  factory _City.fromJson(Map<String, dynamic> j) => _City(
        code: j['code'] as String,
        name: j['name'] as String,
      );
}

class _PaymentMethod {
  const _PaymentMethod(
      {required this.code, required this.name, required this.url});
  final String code;
  final String name;
  final String url;
  factory _PaymentMethod.fromJson(Map<String, dynamic> j) => _PaymentMethod(
        code: j['code'] as String,
        name: j['name'] as String,
        url: j['url'] as String? ?? '',
      );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
