import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../services/referral_api.dart';
import '../theme/app_theme.dart';
import 'auth/phone_screen.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _api = ReferralApi();

  ReferralInfo? _info;
  ReferralStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await context.read<AuthProvider>().getAccessToken();
      if (!mounted || token == null) return;

      final results = await Future.wait([
        _api.getOrCreateCode(token),
        _api.getStats(token),
      ]);

      if (!mounted) return;
      setState(() {
        _info = results[0] as ReferralInfo;
        _stats = results[1] as ReferralStats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить данные. Проверьте соединение.';
      });
    }
  }

  void _copyCode() {
    final code = _info?.code;
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Код скопирован'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share() async {
    final info = _info;
    if (info == null || info.code.isEmpty) return;
    final text = 'Привет! Скачай YokoMarket и введи мой код ${info.code} '
        'при регистрации — получишь ${_fmt(info.bonusUser)} бонусов '
        'на первый заказ! 🛍️';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Пригласить друга',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return _GuestPrompt(
        onLogin: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PhoneScreen()),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
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

    final info = _info!;
    final stats = _stats!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _CodeCard(
          info: info,
          onCopy: _copyCode,
          onShare: _share,
        ),
        const SizedBox(height: 16),
        _ConditionsCard(info: info),
        if (stats.referredCount > 0) ...[
          const SizedBox(height: 16),
          _StatsCard(stats: stats),
        ],
      ],
    );
  }
}

// ── Code card ──────────────────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.info,
    required this.onCopy,
    required this.onShare,
  });

  final ReferralInfo info;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D35D4), Color(0xFF9B5DE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardBorder,
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ВАШ КОД ПРИГЛАШЕНИЯ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  info.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
              ),
              _IconBtn(
                icon: Icons.copy_rounded,
                tooltip: 'Скопировать код',
                onTap: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text(
                'Поделиться',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.purple,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Conditions card ────────────────────────────────────────────────────────────

class _ConditionsCard extends StatelessWidget {
  const _ConditionsCard({required this.info});
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Как это работает',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _Step(
            step: '1',
            text: 'Поделитесь кодом с другом',
          ),
          const SizedBox(height: 12),
          _Step(
            step: '2',
            text: 'Друг скачивает YokoMarket и вводит ваш код при регистрации',
          ),
          const SizedBox(height: 12),
          _Step(
            step: '3',
            text:
                'Друг сразу получает ${_fmt(info.bonusUser)} бонусов на первый заказ',
            highlight: true,
          ),
          const SizedBox(height: 12),
          _Step(
            step: '4',
            text:
                'Вы получаете ${_fmt(info.bonusReferrer)} бонусов после первого заказа друга',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.text, this.highlight = false});

  final String step;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: highlight ? AppColors.purple : AppColors.purpleSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: highlight ? Colors.white : AppColors.purple,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: TextStyle(
                color: highlight ? AppColors.navy : AppColors.navyMuted,
                fontSize: 14,
                height: 1.4,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats card ─────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final ReferralStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ваша команда',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${stats.referredCount} чел.',
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (stats.bonusesEarned > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Заработано бонусов: ${_fmt(stats.bonusesEarned)} YoCoin',
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (int i = 0; i < stats.team.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1, color: AppColors.border),
            _TeamRow(member: stats.team[i]),
          ],
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.member});
  final ReferralTeamMember member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.purpleSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.purple,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${member.orders} ${_ordersWord(member.orders)}',
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (member.total > 0)
            Text(
              '${_fmt(member.total)} ₸',
              style: const TextStyle(
                color: AppColors.navyMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Guest prompt ───────────────────────────────────────────────────────────────

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded,
                size: 64, color: AppColors.purple),
            const SizedBox(height: 16),
            const Text(
              'Войдите, чтобы получить\nкод приглашения',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Приглашайте друзей и получайте бонусы\nза каждого нового участника',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navyMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onLogin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Войти', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmt(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

String _ordersWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 19) return 'заказов';
  if (mod10 == 1) return 'заказ';
  if (mod10 >= 2 && mod10 <= 4) return 'заказа';
  return 'заказов';
}
