# Agent instructions — YokoMarket

## Before creating or modifying any UI screen or widget

Read `.claude/skills/yoko-design.md` first.

It defines:
- Colour tokens (`AppColors.*`) — no hardcoded hex values
- Typography scale — Roboto, Russian/Kazakh/₸ support
- Spacing, border radii (`AppRadii.*`)
- Icon library (Material Icons, rounded style)
- Logo usage rules (app header only, not on packaging)
- Category tile pattern
- Product card layout order (photo → price → name → package → button)
- Button and interactive states (loading, error, empty, disabled)
- Banner carousel rules and tap routing
- Bottom navigation tab order and styling
- Text overflow / large-font rules
- Pre-ship checklist

## General

- Run `flutter analyze` before declaring any code task complete.
- Run `flutter test` before pushing.
- Search field lives on the Catalog tab only — never add it to Home.
- New shared UI components go in `lib/widgets/`, not inline in screens.

---

## Правила для новых экранов

### 1. Дизайн
Экраны собираются только из виджетов `lib/widgets/ui/` и токенов темы (`AppColors.*`, `AppRadii.*`, `AppSpacing.*`). Никаких захардкоженных цветов, шрифтов и отступов прямо в экранах. Источник дизайна — Figma «Yo Market — Full Mobile App», светлая тема.

### 2. Данные
Экраны не создают `Dio` сами. Данные — через провайдер или сервис в `lib/services/`. Использовать существующий Dio-клиент с авторизацией и refresh-токенами.

### 3. Отсутствующий эндпоинт
Если нужного эндпоинта нет в API (см. `PROJECT_OVERVIEW.md` и `BACKEND_AUDIT.md`):
- создай абстрактный класс сервиса и две реализации: `Http…` (вызывает предполагаемый эндпоинт) и `Mock…` (реалистичные данные + задержка 500 мс);
- выбор реализации — через флаг в `AppConfig`: `--dart-define=MOCK_<ИМЯ>=true`, по умолчанию `true`, пока эндпоинт не готов;
- добавь эндпоинт в `API_CONTRACT.md`: метод, путь, авторизация, тело запроса, JSON-ответ с примером, коды ошибок, какой экран использует, статус «ожидает бэкенд».

### 4. Состояния экрана
Каждый экран обрабатывает четыре состояния: загрузка (`Skeleton`), ошибка (`ErrorState` с «Повторить»), пусто (`EmptyState`), данные.

### 5. Тексты и деньги
Тексты — на русском, как в макете. Суммы — через общий форматтер: `formatMoney(amount)` → `5 990 ₸`.

### 6. Навигация
`Navigator.push(MaterialPageRoute(…))`. Каждый новый экран — отдельный файл в `lib/screens/`.

### 7. Качество после каждого экрана
`flutter analyze` без ошибок, коммит в git с понятным сообщением.

### 8. Отчёт в конце работы
Краткий список: созданные/изменённые файлы, какие эндпоинты используются (реальные / мок), что проверить вручную.

### 9. Программа лояльности — источник правды Figma
Бэкенд будет переделан; Figma главнее текущего `BACKEND_AUDIT.md` в этой части.

**Модель кэшбэка (месячный, по сумме покупок за календарный месяц):**

| Сумма покупок за месяц | Кэшбэк |
|---|---|
| от 50 000 ₸ | 3 % |
| от 100 000 ₸ | 5 % |
| от 200 000 ₸ | 10 % |

- Кэшбэк начисляется YoCoin после окончания месяца; до начисления показывается как «предварительный».
- 1 YoCoin = 1 ₸; оплата бонусами до 100 % заказа.
- 1 000 YoCoin за регистрацию; 300 YoCoin за приглашённого друга.
- Бесплатная доставка от 10 000 ₸ в зоне доставки.

**Реализация:**
- Цифры в экранах не хардкодить: модель `LoyaltyRules` из `LoyaltyApi`.
- Реализации `HttpLoyaltyApi` и `MockLoyaltyApi` с цифрами выше; флаг `MOCK_LOYALTY=true` по умолчанию.
- Нужные эндпоинты описать в `API_CONTRACT.md`: правила, баланс, кэшбэк за текущий месяц, история операций с причиной начисления.

**Суммы к оплате и списание бонусов в корзине / оформлении — только из ответа `POST /checkout/estimate`, никогда не считать на клиенте.**
