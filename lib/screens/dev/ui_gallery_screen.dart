import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui/ui.dart';

const bool _kUiPreview =
    bool.fromEnvironment('UI_PREVIEW', defaultValue: false);

/// Opens gallery only in UI preview build.
/// Usage: flutter run --dart-define=UI_PREVIEW=true
void openUiGallery(BuildContext context) {
  if (!_kUiPreview) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const UiGalleryScreen()),
  );
}

class UiGalleryScreen extends StatefulWidget {
  const UiGalleryScreen({super.key});

  @override
  State<UiGalleryScreen> createState() => _UiGalleryScreenState();
}

class _UiGalleryScreenState extends State<UiGalleryScreen> {
  String? _selectedChip = 'Все';
  bool _optionA = true;
  bool _optionB = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('UI Gallery')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.xl,
        ),
        children: [
          _Section('Buttons', children: [
            AppButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: 8),
            AppButton(
              label: 'Secondary',
              onPressed: () {},
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(height: 8),
            const AppButton(
              label: 'Disabled',
              variant: AppButtonVariant.disabled,
            ),
            const SizedBox(height: 8),
            AppButton(label: 'Loading…', onPressed: () {}, loading: true),
          ]),
          _Section('Text Fields', children: [
            const AppTextField(label: 'Имя', hint: 'Введите имя'),
            const SizedBox(height: 12),
            const AppTextField(
              label: 'С ошибкой',
              hint: 'Введите значение',
              errorText: 'Неверный или истёкший код',
            ),
            const SizedBox(height: 12),
            const PhoneTextField(),
          ]),
          _Section('Cards', children: [
            AppCard(child: const Text('AppCard — белая карточка radius 20')),
            const SizedBox(height: 12),
            NavRow(
              title: 'Мои заказы',
              subtitle: 'Статусы и история покупок',
              onTap: () {},
            ),
          ]),
          _Section('Chips', children: [
            ChipGroup(
              items: const ['Все', 'Подгузники', 'Трусики', 'Пелёнки'],
              selected: _selectedChip,
              onSelected: (v) => setState(() => _selectedChip = v),
              padding: EdgeInsets.zero,
            ),
          ]),
          _Section('Option Cards', children: [
            OptionCard(
              title: 'Доставка курьером',
              subtitle: '1–2 рабочих дня',
              selected: _optionA,
              onTap: () => setState(() {
                _optionA = true;
                _optionB = false;
              }),
            ),
            const SizedBox(height: 8),
            OptionCard(
              title: 'Самовывоз',
              subtitle: 'г. Алматы, пр. Абая 10',
              selected: _optionB,
              onTap: () => setState(() {
                _optionA = false;
                _optionB = true;
              }),
            ),
          ]),
          _Section('Status Chips', children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrderStatusVariant.values
                  .map((s) => StatusChip(status: s))
                  .toList(),
            ),
          ]),
          _Section('Hero Balance Card', children: [
            HeroBalanceCard(
              topLabel: 'Мои YoCoin',
              value: '1 250',
              unit: 'монет',
              subtitle: 'Действуют бессрочно',
            ),
          ]),
          _Section('Promo Card', children: [
            PromoCard(
              title: 'Пригласите друга',
              body: 'Вы получите 500 монет за каждого приглашённого',
              onTap: () {},
              leading: const Icon(
                Icons.card_giftcard,
                color: AppColors.navy,
                size: 28,
              ),
            ),
          ]),
          _Section('Progress Card', children: [
            AppCard(
              child: ProgressCard(
                title: 'До Bronze',
                subtitle: 'Копите покупки — повышайте кэшбэк',
                progress: 0.45,
                startLabel: '0',
                endLabel: '20 000 ₸',
                progressLabel: '9 000 из 20 000',
              ),
            ),
          ]),
          _Section('Step Header', children: [
            StepHeader(current: 2, total: 3),
          ]),
          _Section('Summary Rows', children: [
            AppCard(
              child: SummaryRows(
                rows: buildOrderSummaryRows(
                  subtotal: 5990,
                  delivery: 0,
                  discount: 300,
                  bonusUsed: 100,
                  total: 5590,
                ),
              ),
            ),
          ]),
          _Section('Product Card', children: [
            SizedBox(
              width: 180,
              child: ProductCard(
                name: 'Подгузники Yokosun Premium',
                price: 3490,
                regularPrice: 4200,
                size: 'L',
                meta: '9–14 кг · 42 шт',
                onTap: () {},
                onAddToCart: () {},
              ),
            ),
          ]),
          _Section('Empty State', children: [
            EmptyState(
              headline: 'Корзина пуста',
              body: 'Добавьте товары из каталога',
              actionLabel: 'Перейти в каталог',
              onAction: () {},
            ),
          ]),
          _Section('Error State', children: [
            ErrorState(
              message: 'Проверьте подключение к интернету',
              onRetry: () {},
              onBack: () {},
            ),
          ]),
          _Section('Skeleton', children: [
            Skeleton.rect(width: double.infinity, height: 20),
            const SizedBox(height: 8),
            Skeleton.rect(width: 180, height: 14),
            const SizedBox(height: 8),
            Row(
              children: [
                Skeleton.circle(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.rect(height: 16),
                      const SizedBox(height: 6),
                      Skeleton.rect(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ]),
          _Section('Screen Header', children: [
            ScreenHeader(
              title: 'Бонусная программа',
              backLabel: 'Профиль',
              onBack: () {},
            ),
          ]),
          _Section('Money Text', children: [
            MoneyText(5990),
            const SizedBox(height: 8),
            MoneyText(15000, size: 24, weight: FontWeight.w800),
            const SizedBox(height: 8),
            Text(formatMoney(1234567)),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
