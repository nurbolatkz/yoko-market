---
description: YokoMarket Flutter design system — read before creating or modifying any UI screen or widget.
---

# YokoMarket Design System

## 1. Colour palette

Always use `AppColors` from `lib/theme/app_theme.dart`. Never hardcode hex values in widget files.

| Token | Hex | Use |
|---|---|---|
| `AppColors.background` | `#FAF9F6` | Scaffold / page background |
| `AppColors.surface` | `#FFFFFF` | Cards, bottom sheets, nav bar |
| `AppColors.navy` | `#202039` | Primary text |
| `AppColors.navyMuted` | `#66637A` | Secondary / hint text |
| `AppColors.purple` | `#6D35D4` | Brand primary — CTAs, selected states |
| `AppColors.purpleDark` | `#5428AB` | Pressed / hover purple |
| `AppColors.purpleSoft` | `#EDE8FA` | Purple tint — nav indicator, category bg |
| `AppColors.yellow` | `#FFD84F` | Logo accent, badge background |
| `AppColors.border` | `#EEECD3` | Dividers, card borders |

## 2. Typography

Font: **Roboto** — set globally in `AppTheme`; never override `fontFamily` inside individual widgets.
Covers Russian (ru), Kazakh (kk), and the ₸ symbol.

Use named styles from `Theme.of(context).textTheme`:

| Role | Style | Weight | Approx size |
|---|---|---|---|
| Screen / AppBar title | `headlineSmall` | w700 | 24 |
| Section header | `titleLarge` | w700 | 22 |
| Card title / price | `titleMedium` | w600 | 16 |
| Body copy | `bodyMedium` | w400 | 14 |
| Caption / hint / label | `bodySmall` | w400 | 12 |
| Button label | `labelLarge` | w700 | 14 |

For the inline brand logo only (`RichText('Yo' + ' Market')`), explicit `TextStyle` is acceptable — but always wrap in `Flexible` to prevent overflow on narrow screens.

**All text in a `Row` must have `Flexible`, `Expanded`, or `ConstrainedBox(maxWidth:…)` — never unbounded.**

## 3. Spacing and border radii

| Token / value | Use |
|---|---|
| `AppRadii.card` = 20 | Product cards, image containers |
| `AppRadii.button` = 14 | All buttons, chips |
| `AppRadii.input` = 14 | TextFields |
| 16 *(proposed)* | Category tile rounded squares |
| 16 | Horizontal page padding |
| 24 | Gap between screen sections |
| 12 | Inner padding inside product / promo cards |
| 18 | Gap between header and first section |

## 4. Icon library

Use **Material Icons only** — `Icons.*` from Flutter's standard library.
Preferred style: **rounded** suffix (`Icons.home_rounded`, `Icons.grid_view_rounded`).
Outlined variants for unselected / secondary states.
Sizes: 24 in nav bar, 20–24 in body, 13–16 for inline label icons.
**Never mix icon families** (no CupertinoIcons, FontAwesome, etc.).

## 5. Logo — app header only

Logo #1 (header of the app — **not** for product packaging, print, or partner materials):

```
SizedBox(32 × 32)
  Stack:
    Container(32 × 32, circle, fill: AppColors.yellow)
    Center → Text('Y', color: AppColors.purple, fontSize: 20, w900)
Followed by:
  Flexible → RichText(
    'Yo'     TextSpan(color: AppColors.purple, fontSize: 20, w900)
    ' Market' TextSpan(color: AppColors.navy,   fontSize: 20, w900)
  )
```

Do not render this logo on product cards, packaging descriptions, or banners.

## 6. Category tiles

- Shape: `ClipRRect(borderRadius: BorderRadius.circular(16))` around a fixed-size square.
- Background: `AppColors.purpleSoft` when no image.
- Image: load via `Image.network` with `BoxFit.cover`; fall back to icon on error.
- Fallback icon: `Icons.category_outlined`, centred, `AppColors.navyMuted`.
- Label: below the tile, `bodySmall` style, `textAlign: center`, `maxLines: 2`, `overflow: ellipsis`.
- Tap: calls `onCategorySelected(category.name)` — switches to the Catalog tab pre-filtered.
  **Search field is on the Catalog tab only; never add it to Home.**

## 7. Product card layout

Top-to-bottom order is fixed:

1. **Photo** (flex 5) — `ProductImage(imageUrl: product.imageUrl)`  
   from `lib/widgets/product_image.dart`. Top corners use `AppRadii.card`.
2. **Price** — `titleMedium`, navy. If promo price: show promo in purple, original struck-through in `bodySmall` navyMuted.
3. **Name** — `bodyMedium`, navy, `maxLines: 2`, `overflow: ellipsis`.
4. **Package info** — `bodySmall`, navyMuted (e.g. "24 шт").
5. **Bottom row** — stock text on left, add-to-cart button on right.

Out-of-stock: `opacity 0.55` on the card, add button `onPressed: null`, label "Нет в наличии".

## 8. Buttons and interactive states

| Type | Widget | Style |
|---|---|---|
| Primary (add to cart, confirm) | `FilledButton` | Purple bg, white text, `AppRadii.button` |
| Secondary | `OutlinedButton` | Purple border + text |
| Tertiary / remove | `TextButton` | `AppColors.navyMuted` |

States:
- **Loading**: `SizedBox(18, 18)` wrapping `CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple)`.
- **Error + retry**: `bodySmall` navyMuted message + `TextButton('Повторить')`.
- **Empty state**: centred icon (48, navyMuted) + `bodyMedium` text + optional retry.
- **Disabled**: pass `onPressed: null` — Flutter auto-dims; do not fake disable with color overrides.

## 9. Banner carousel

- Hidden entirely (`provider.banners.isEmpty` → render nothing, no placeholder).
- Card height: 160. Border radius: `AppRadii.card`.
- Background: `LinearGradient` parsed from the `bg_color` API field, or solid `AppColors.purpleSoft`.
- Tap routing:
  - `banner.isPromoOrGiveaway == true` → `Navigator.push(…, PromotionDetailScreen(bannerId: banner.id))`.
  - Regular banner → no navigation.
- Dot indicators: `AppColors.yellow` active, `AppColors.surface.withValues(alpha: 0.5)` inactive.

## 10. Bottom navigation (NavigationBar)

5 tabs in order: **Главная · Каталог · Корзина · Избранное · Профиль**.
Height: 74. Material 3 `NavigationBar` — already styled in `AppTheme`.
Cart tab: `Badge(label: Text('$cartCount'))` with yellow bg / navy text when `cartCount > 0`.
Do not change tab order or labels without explicit agreement.

## 11. Text scaling / large font handling

Layouts must not overflow at `textScaleFactor` up to 1.5×:
- `Row` children with text: wrap in `Flexible` or `Expanded`.
- City selector (header): `ConstrainedBox(maxWidth: 50)` + `overflow: ellipsis`.
- Bottom nav labels: `overflow: ellipsis` already set in `AppTheme.navigationBarTheme`.
- Product card name: `maxLines: 2`, `overflow: ellipsis`.
- The test environment uses the Ahem font (1 char = 1 em width) — layout must not overflow even there.

## 12. Pre-ship screen checklist

Before marking any UI task complete:

- [ ] All colours are `AppColors.*` tokens — zero hardcoded hex.
- [ ] All text uses theme styles or explicit sizes matching this spec.
- [ ] No unbounded `Text` in a `Row` — each has `Flexible`, `Expanded`, or `ConstrainedBox`.
- [ ] Loading, error, and empty states are handled for every async data source.
- [ ] `flutter analyze` → zero warnings.
- [ ] `flutter test` → all tests pass.
- [ ] Search field appears only on Catalog tab, not Home.
- [ ] New widgets reuse `ProductImage` from `lib/widgets/product_image.dart`; no inline image-load duplication.

## 13. Key file paths

| What | Path |
|---|---|
| Colours, radii, full ThemeData | `lib/theme/app_theme.dart` |
| ProductImage + placeholder | `lib/widgets/product_image.dart` |
| Home screen (tab index 0) | `lib/screens/catalog_screen.dart` |
| Catalog screen (tab index 1) | `lib/screens/product_catalog_screen.dart` |
| Nav shell + tab order | `lib/screens/main_screen.dart` |
| MarketProvider (cart, products, banners) | `lib/providers/market_provider.dart` |
| BannerItem model | `lib/models/banner_item.dart` |
| ProductCategory model | `lib/models/product_category.dart` |
| PromotionDetailScreen (stub) | `lib/screens/promotion_detail_screen.dart` |

## 14. Priorities

1. Most recent agreed task description (in the current conversation).
2. This skill.
3. Older mockups or screenshots (may be outdated — flag conflicts instead of silently using them).

Mark unconfirmed sizes or patterns as ***(proposed)*** so reviewers know they haven't been locked in.
