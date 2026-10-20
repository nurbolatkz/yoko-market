import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  List<_FaqNode> _roots = [];
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
      final resp = await _dio.get<dynamic>('/support/tree');
      final raw = resp.data;
      if (raw is! List) throw Exception('unexpected');
      final nodes = raw.whereType<Map<String, dynamic>>().toList();
      setState(() {
        _roots = _buildTree(nodes);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.message ?? 'Ошибка сети';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Не удалось загрузить FAQ';
        _loading = false;
      });
    }
  }

  List<_FaqNode> _buildTree(List<Map<String, dynamic>> raw) {
    final roots = raw.where((n) => n['parent_id'] == null).toList();
    roots.sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));

    return roots.map((r) {
      final children = raw
          .where((n) => n['parent_id'] == r['id'])
          .toList()
        ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));

      return _FaqNode(
        label: r['button_label'] as String,
        answer: r['bot_message'] as String,
        action: r['action'] as String,
        children: children
            .map(
              (c) => _FaqNode(
                label: c['button_label'] as String,
                answer: c['bot_message'] as String,
                action: c['action'] as String,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  Future<void> _openManager() async {
    const url = 'https://t.me/yokosun_bot';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Поддержка',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _ContactBanner(onTap: _openManager),
        const SizedBox(height: 24),
        const Text(
          'Часто задаваемые вопросы',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        for (final node in _roots)
          _FaqTile(node: node, onOpenManager: _openManager),
      ],
    );
  }
}

// ── Contact banner ────────────────────────────────────────────────────────────

class _ContactBanner extends StatelessWidget {
  const _ContactBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.purple,
          borderRadius: AppRadii.cardBorder,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headset_mic_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Написать менеджеру',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Telegram @yokosun_bot',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAQ tile ──────────────────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.node, required this.onOpenManager});

  final _FaqNode node;
  final VoidCallback onOpenManager;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.cardBorder,
        child: InkWell(
          borderRadius: AppRadii.cardBorder,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.label,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.navyMuted,
                      size: 20,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  if (hasChildren)
                    _ChildList(
                      children: node.children,
                      onOpenManager: widget.onOpenManager,
                    )
                  else ...[
                    if (node.answer.isNotEmpty) ...[
                      Text(
                        node.answer,
                        style: const TextStyle(
                          color: AppColors.navyMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (node.action == 'open_manager')
                      _ContactButton(onTap: widget.onOpenManager),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Child list inside expanded tile ──────────────────────────────────────────

class _ChildList extends StatefulWidget {
  const _ChildList({required this.children, required this.onOpenManager});

  final List<_FaqNode> children;
  final VoidCallback onOpenManager;

  @override
  State<_ChildList> createState() => _ChildListState();
}

class _ChildListState extends State<_ChildList> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _SubTile(
            node: widget.children[i],
            isOpen: _openIndex == i,
            onToggle: () => setState(() => _openIndex = _openIndex == i ? null : i),
            onOpenManager: widget.onOpenManager,
          ),
      ],
    );
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({
    required this.node,
    required this.isOpen,
    required this.onToggle,
    required this.onOpenManager,
  });

  final _FaqNode node;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onOpenManager;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      node.label,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.navyMuted,
                    size: 16,
                  ),
                ],
              ),
              if (isOpen && node.answer.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  node.answer,
                  style: const TextStyle(
                    color: AppColors.navyMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (node.action == 'open_manager') ...[
                  const SizedBox(height: 8),
                  _ContactButton(onTap: onOpenManager),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contact button ────────────────────────────────────────────────────────────

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.send_rounded, size: 16),
        label: const Text('Написать менеджеру'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purple,
          side: const BorderSide(color: AppColors.purple),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

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
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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

// ── Data model ────────────────────────────────────────────────────────────────

class _FaqNode {
  const _FaqNode({
    required this.label,
    required this.answer,
    required this.action,
    this.children = const [],
  });

  final String label;
  final String answer;
  final String action;
  final List<_FaqNode> children;
}
