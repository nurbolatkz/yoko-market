# Component Rules — YokoMarket
*Source: `lib/widgets/ui/`, `lib/screens/` — verified 2026-11-09*

## State contract (applies to every async component)

| State | Requirement |
|---|---|
| **loading** | `Skeleton` widget; no layout jump vs loaded state |
| **empty** | Centred icon (48 dp, `navyMuted`) + `bodyMedium` text + optional retry button |
| **error** | `bodySmall navyMuted` message + `TextButton('Повторить')` |
| **disabled** | `onPressed: null` — Flutter auto-dims; never fake-disable with color overrides |
| **success** | Immediate transition or green (`AppColors.success`) indicator |

---

## Header / AppBar

- Background: `AppColors.background`; elevation 0; `centerTitle: false`.
- Left: logo (yellow circle + "Yo Market" RichText) — never on product cards or banners.
- City selector: `ConstrainedBox(maxWidth: 50)` + `overflow: ellipsis` for long names.
- Right actions: icons only (search, notifications). Search field lives on **Catalog tab only**.
- AppBar title style: `NunitoSans, 24 px, w800, AppColors.navy`.

## Search field

- Catalog tab only. Home tab must not have an inline search `TextField`.
- State: idle border `AppColors.border`; focused border `AppColors.purple (1.5 dp)`.
- Error: `AppColors.error` border + inline `bodySmall` message.

## Banner carousel

- Hidden when `banners.isEmpty` — no placeholder, no height reservation.
- Card height: 160 dp. Border radius: `AppRadii.card`.
- Image: `LayoutBuilder` → `cacheWidth = (constraints.maxWidth × devicePixelRatio).ceil().clamp(800, 2048)`.
- Background fallback: `LinearGradient` from `bg_color` API field, or `AppColors.purpleSoft`.
- "Подробнее" chip: Flutter `Positioned` overlay widget — never drawn into the image asset.
- Tap routing: `isPromoOrGiveaway == true` → `PromotionDetailScreen(bannerId)`, else no-op.
- Dot indicators: `AppColors.yellow` active, `AppColors.surface.withValues(alpha: 0.5)` inactive.
- States: loading → `Skeleton(height: 160, radius: AppRadii.card)`; error → silent omit.

## Category tile

- 4 tiles per row; max 8 displayed (4 × 2). Order from backend `set_home` field.
- Shape: `ClipRRect(BorderRadius.circular(AppRadii.image))` over a fixed square.
- Background: `AppColors.purpleSoft` when no image.
- Image: `Image.network`, `BoxFit.cover`; fallback `Icons.category_outlined, AppColors.navyMuted`.
- Label: `bodySmall`, `textAlign: center`, `maxLines: 2`, `overflow: ellipsis`.
- Tap: `onCategorySelected(category.name)` → switch to Catalog tab pre-filtered.
- At `textScaleFactor` > 1.3: allow label to wrap without clipping the tile.
- States: loading → `Skeleton.rect(height: tile_size, radius: AppRadii.image)`.

## Product card

Order fixed top-to-bottom:
1. **Photo** (flex 5) — `ProductImage(imageUrl: product.imageUrl)` from `lib/widgets/product_image.dart`.
2. **Price** — `titleMedium`, `AppColors.navy`. Promo: show promo in purple, original struck-through in `bodySmall navyMuted`.
3. **Name** — `bodyMedium`, navy, `maxLines: 2`, `overflow: ellipsis`.
4. **Package** — `bodySmall`, navyMuted (e.g. "24 шт").
5. **Bottom row** — stock text left, add-to-cart button right.

Out-of-stock: `Opacity(0.55)` on card, button `onPressed: null`, label "Нет в наличии".
Loading: skeleton column matching card dimensions.

## Price display

- Regular: `titleMedium, AppColors.navy`.
- Promo: promo price `titleMedium, AppColors.purple` + original `bodySmall, navyMuted, TextDecoration.lineThrough`.
- Currency symbol: `₸` — always after the number (`1 490 ₸`).
- Do not invent discounts or promo prices not present in API data.

## Stock / availability

- In stock: `AppColors.success` dot or text "В наличии".
- Low stock: `AppColors.yellow` indicator (threshold defined by backend).
- Out of stock: `AppColors.navyMuted`, button disabled.
- Do not display stock numbers not provided by the API.

## Quantity stepper

- Min size per cell: 48 × 48 dp.
- States: at min → decrement button disabled; at stock limit → increment disabled.
- Loading: show `CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple)` in place of value.

## Cart (bottom nav badge)

- Badge: `Badge(label: Text('$count'))` on Cart nav item, `AppColors.yellow` bg / `AppColors.navy` text.
- No floating cart panel over Home content — cart count visible via nav badge only.

## CTA buttons

| Variant | Widget | Use |
|---|---|---|
| Primary | `FilledButton` / `AppButton(variant: .primary)` | Add to cart, confirm, pay |
| Secondary | `AppButton(variant: .secondary)` | Secondary actions (purpleSoft bg) |
| Outlined | `OutlinedButton` | Cancel, back-to-catalog |
| Text | `TextButton` | Destructive / tertiary (navyMuted) |

Loading inside button: `SizedBox(18,18)` → `CircularProgressIndicator(strokeWidth: 2, color: white)`.
Minimum height: 52 dp (set in `AppTheme`).

## Tabs (NavigationBar)

5 tabs in fixed order: **Главная · Каталог · Корзина · Избранное · Профиль**.
Height: 72 dp. Do not reorder or rename without explicit agreement.
Selected icon: filled/rounded variant. Unselected: outlined variant.

## Forms and OTP

- `TextField` uses `InputDecorationTheme` from `AppTheme` — never override border or fill manually.
- Focused border: `AppColors.purple, 1.5 dp`. Error border: `AppColors.error`.
- OTP / PIN cells: 48 × 48 dp minimum; filled `AppColors.purpleSoft` when empty, `AppColors.purple` border when active.
- Error: `AppColors.error` border + `bodySmall` inline message below the field — not a snackbar for field-level errors.
- Success: immediate navigation; no artificial delay.
- Keyboard: use `keyboardType` and `textInputAction` to give users the right keyboard.

## Skeleton

Use `Skeleton` widget from `lib/widgets/ui/skeleton.dart`:
- `Skeleton.rect(width: ..., height: ..., radius: ...)` — rectangular areas.
- `Skeleton.circle(size: ...)` — avatars, icons.
- Background: `AppColors.purpleSoft`; 1 200 ms pulse animation.
- Skeletons must match the loaded layout dimensions to avoid reflow.

## EmptyState

Use `EmptyState` widget from `lib/widgets/ui/empty_state.dart`.
- `icon`: centred, 48 dp, `AppColors.navyMuted`.
- `headline`: `NunitoSans, 22 px, w800`.
- `body`: `bodyMedium / bodySmall, navyMuted`.
- Optional `AppButton` action.

---

## Promotion detail screen

| Element | Rule |
|---|---|
| AppBar title | `giveaway` → "Розыгрыш"; default → "Подборка" |
| Hero image | `BoxFit.fitWidth`, `width: double.infinity` — full image, no cropping |
| Ended banner | `AppColors.yellowSoft` bg + `AppColors.navy` text (use tokens, not hardcoded hex) |
| Sections | Render from `sections` JSON; `full_description` text as plain fallback |
| CTA (hasAction) | `_ActionButton` with product or catalog routing |
| CTA (no action) | `_CatalogButton` — "Смотреть товары", same `FilledButton` style |
| Spacing | top padding 12 dp, section gap 20 dp, button margin-top 24 dp |
| Description text | `AppColors.navy` (not `navyMuted`) — full contrast |
