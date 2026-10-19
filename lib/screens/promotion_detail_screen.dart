import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/market_provider.dart';
import '../theme/app_theme.dart';

class PromotionDetailScreen extends StatefulWidget {
  const PromotionDetailScreen({super.key, required this.bannerId});

  final String bannerId;

  @override
  State<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

enum _LoadState { loading, loaded, error, notFound }

class _PromotionDetailScreenState extends State<PromotionDetailScreen> {
  _LoadState _state = _LoadState.loading;
  Map<String, dynamic> _data = const {};
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final data = await context.read<MarketProvider>().getBannerById(widget.bannerId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('404') || msg.contains('banner_not_found')) {
        setState(() => _state = _LoadState.notFound);
      } else {
        setState(() {
          _state = _LoadState.error;
          _errorMessage = 'Не удалось загрузить акцию. Проверьте подключение.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: BackButton(
          onPressed: () => Navigator.pop(context),
          color: AppColors.navy,
        ),
        title: Text(_appBarTitle),
      ),
      body: switch (_state) {
        _LoadState.loading => const _LoadingBody(),
        _LoadState.error => _ErrorBody(
            message: _errorMessage,
            onRetry: _load,
          ),
        _LoadState.notFound => const _NotFoundBody(),
        _LoadState.loaded => _ContentBody(data: _data),
      },
    );
  }

  String get _appBarTitle {
    if (_state != _LoadState.loaded) return 'Акция';
    return _data['promo_type'] == 'giveaway' ? 'Розыгрыш' : 'Акция';
  }
}

// ── Loading ────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.purple,
        ),
      ),
    );
  }
}

// ── Error ──────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

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
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.navyMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.navyMuted),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Not found ─────────────────────────────────────────────────────────────

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.navyMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Акция не найдена',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Возможно, она уже закончилась или была удалена.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.navyMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['image_url'] as String?;
    final title = data['title'] as String? ?? '';
    final subtitle = data['subtitle'] as String?;
    final badge = data['badge'] as String?;
    final fullDescription = data['full_description'] as String?;
    final isEnded = data['is_ended'] as bool? ?? false;
    final validFrom = _parseDate(data['valid_from']);
    final validUntil = _parseDate(data['valid_until']);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isEnded) const _EndedBanner(),
          if (imageUrl != null && imageUrl.isNotEmpty)
            _HeroImage(imageUrl: imageUrl),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null && badge.isNotEmpty) ...[
                  _BadgeChip(label: badge),
                  const SizedBox(height: 12),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.navyMuted),
                  ),
                ],
                if (validFrom != null || validUntil != null) ...[
                  const SizedBox(height: 20),
                  _DateRow(validFrom: validFrom, validUntil: validUntil),
                ],
                if (fullDescription != null && fullDescription.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 20),
                  Text(
                    fullDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  try {
    return DateTime.parse('$value');
  } catch (_) {
    return null;
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _EndedBanner extends StatelessWidget {
  const _EndedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3CD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF856404),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Акция завершена',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF856404),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.purpleSoft,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppColors.navyMuted,
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.purple,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({this.validFrom, this.validUntil});

  final DateTime? validFrom;
  final DateTime? validUntil;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.navyMuted,
    );
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: AppColors.navyMuted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _formatRange(validFrom, validUntil),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatRange(DateTime? from, DateTime? until) {
    final f = from != null ? _fmt(from) : null;
    final u = until != null ? _fmt(until) : null;
    if (f != null && u != null) return '$f — $u';
    if (f != null) return 'С $f';
    if (u != null) return 'До $u';
    return '';
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
