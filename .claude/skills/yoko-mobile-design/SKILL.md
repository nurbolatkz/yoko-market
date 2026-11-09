---
name: yoko-mobile-design
description: >
  YokoMarket Flutter UI/UX skill for iOS & Android. Load this skill before
  creating or editing any screen, widget, or theme file. Covers design tokens,
  component rules, platform behaviour, accessibility, and performance contracts.
  Supersedes the older yoko-design.md (kept as a redirect).
---

# YokoMarket Mobile Design Skill

**Sources verified:** Apple HIG 2024, Material Design 3 (m3.material.io), Flutter docs 3.24, WCAG 2.2 AA — 2026-11-09.

## When to load this skill

Load automatically when the task touches:
- Any file under `lib/screens/`, `lib/widgets/`, or `lib/theme/`
- Design token usage (colors, radii, spacing, typography)
- Image loading, skeletons, or animation
- Platform behaviour (safe areas, back navigation, keyboard)

## Core files

| What | Path |
|---|---|
| Design tokens | `lib/theme/app_theme.dart` |
| Home tab | `lib/screens/catalog_screen.dart` |
| Catalog tab | `lib/screens/product_catalog_screen.dart` |
| Nav shell | `lib/screens/main_screen.dart` |
| Promotion detail | `lib/screens/promotion_detail_screen.dart` |
| ProductImage widget | `lib/widgets/product_image.dart` |
| Shared UI components | `lib/widgets/ui/` |
| Design references | `design-referrences/` |

Full token tables → [`references/tokens.md`](references/tokens.md)
Component state rules → [`references/components.md`](references/components.md)
QA checklist → [`references/qa-checklist.md`](references/qa-checklist.md)
Current deviations → [`references/deviations.md`](references/deviations.md)

---

## 1. Visual system

**Background palette:** lavender background (`AppColors.background = #EDE8FA`), white surfaces, lavender accents, primary purple `#6D35D4`.
**Font:** `NunitoSans` — set globally in `AppTheme`; never override `fontFamily` inside individual widgets.
**Hierarchy:** readability over decoration. No heavy shadows, no blur-for-blur's-sake, no excessive gradients.
**Logo:** use the approved in-code logo (yellow circle + "Y" + "Yo Market" RichText) — do not redesign or render on product cards.

Rule: **all colours must be `AppColors.*` tokens. Zero hardcoded hex in widget files.**

## 2. iOS and Android

- Shared brand identity; platform-native behaviour for Back gestures, keyboard avoidance, `SafeArea`, dialogs, and bottom sheets.
- Minimum tap target: **48 × 48 dp** (HIG) / **48 × 48 dp** (Material) — use `minimumSize` on buttons.
- Support `textScaleFactor` up to **1.5×** without overflow: wrap `Row` text children in `Flexible` or `Expanded`.
- Support **VoiceOver / TalkBack**: add `Semantics` labels on interactive elements that lack visible text.
- Respect `MediaQuery.disableAnimations` — wrap non-essential `AnimationController` starts with a check.
- Do not disable text scaling to match a mockup pixel-perfectly.
- Do not fake system bars with images.

## 3. Component rules (summary)

Every async component must handle: **loading · empty · error · disabled · success** where applicable.

**Home screen:**
- Compact header (logo + city + search icon); search field lives on Catalog tab only.
- Banners: sharp decode via `LayoutBuilder` + `devicePixelRatioOf`, `cacheWidth` clamped 800–2048.
- Categories: 4 per row, max 8 (4 × 2 grid); order from `set_home` backend field.
- Product cards: real photos, prices, stock; no floating cart overlay covering content.
- Cart count: bottom nav badge only.

**Banner detail screen:**
- Full image at native aspect ratio (`BoxFit.fitWidth`).
- Title from `promo_type`: `giveaway` → "Розыгрыш", default → "Подборка".
- Text sections from JSON `sections` field; plain `full_description` as fallback.
- CTA when `hasAction`: `_ActionButton`. CTA when no action: `_CatalogButton("Смотреть товары")`.
- "Подробнее" chip is a Flutter widget overlay — never baked into the image asset.
- Text visible in the banner image must not be duplicated as Flutter text on top.

**OTP / auth forms:**
- PIN pad: 48 × 48 dp minimum cells.
- Error state: `AppColors.error` border, inline message in `bodySmall`.
- Success: immediate transition; no fake delay.

## 4. Performance

- First frame must not wait for API calls — `MainScreen` always in tree; overlays on top.
- Use `Skeleton` widget (`lib/widgets/ui/skeleton.dart`) for loading; no layout jumps.
- Images: use `ProductImage` widget for products; use `LayoutBuilder` + `cacheWidth` for banners.
- Animations ≤ 400 ms, interruptible. Do not claim "fast" without profile/release measurements.
- Lazy lists (`ListView.builder`); do not expand unbounded `ListView` inside `Column`.

## 5. Business logic preservation

Redesign must not alter: API contracts, auth flow, stock/price logic, city/branch filtering, cart state, or pre-launch feature flags. Do not invent discounts, reviews, delivery times, or product properties not in the API. Do not create non-functional buttons. List missing assets explicitly rather than substituting placeholder art.

## 6. Workflow for each UI task

a) Understand the specific screen and user goal.
b) Read existing components and data models before proposing changes.
c) Propose minimal targeted changes; share a before/after if the diff is non-trivial.
d) Implement only the agreed scope.
e) Verify at 360 dp, 390 dp, long Russian text, 1.5× text scale, and open keyboard where relevant.
f) Run `flutter analyze --no-pub` → zero errors before marking done.

If mockup requested → deliver visual ASCII/text concept first.
If implementation requested → do not stop at description; write the code.
Do not trigger a full app audit for a small UI fix.
Do not add new pub dependencies without a concrete reason.

---

## Example invocations

```
/yoko-mobile-design  Home screen: add a "Новинки" section below banners
/yoko-mobile-design  BannerDetail: show sections list with sticky CTA button
/yoko-mobile-design  OTP screen: improve error state accessibility
```

See [`references/components.md`](references/components.md) for detailed state tables.
