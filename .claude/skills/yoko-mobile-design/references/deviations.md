# Current UI Deviations
*Snapshot: 2026-11-09 (branch: main, after PR #34 merge)*

Deviations from the rules in this skill, ordered by impact.

---

## High — fix before next release

### 1. Hardcoded hex in `promotion_detail_screen.dart`

**`_EndedBanner`** (line ~642):
```dart
color: const Color(0xFFFFF3CD)   // should be AppColors.yellowSoft (#FFF8D6, close but not same)
color: const Color(0xFF856404)   // no token; needs AppColors.warning or use navyMuted
```
**`_PrizeSection`** gradient:
```dart
Color(0xFF6C5CE7), Color(0xFF9B59B6)  // no token; closest: AppColors.purple + AppColors.purpleDark
```
Action: add `AppColors.warning = Color(0xFF856404)` token or use `navyMuted`; replace hardcoded gradient with brand colors.

---

## Medium — improve in next design pass

### 2. No reduced-motion support in `WelcomeOverlay`

`WelcomeOverlay` (`lib/screens/welcome_screen.dart`) plays a 2 800 ms animation unconditionally.
Should check `MediaQuery.disableAnimations` and skip to the final state immediately if true.

### 3. Missing `Semantics` labels on icon-only buttons

Several screens use `IconButton` or `GestureDetector` without `Semantics(label:...)`:
- Home header cart icon
- Product card wishlist (heart) icon
- Banner dot indicators

Action: add `tooltip` on `IconButton` (Flutter auto-converts to Semantics) or explicit `Semantics`.

### 4. Floating cart trigger removed but `onCartTapped` callback still present

`MainScreen` passes `onCartTapped` to `CatalogScreen` for the removed floating cart panel.
The callback is harmless but dead code — clean up when convenient.

---

## Low — documentation only

### 5. Old `yoko-design.md` skill contained wrong values

The file `.claude/skills/yoko-design.md` (now a redirect) listed:
- Font: `Roboto` → actual: **`NunitoSans`**
- `background`: `#FAF9F6` (warm beige) → actual: **`#EDE8FA`** (lavender = `purpleSoft`)
- `border`: `#EEECD3` → actual: **`#EEECF3`**

These are corrected in this skill. Code was always correct; only the documentation was wrong.

### 6. `_RetryImage` comment in `catalog_screen.dart`

A multi-line code comment was added to `_RetryImage.cacheWidth` field explaining its purpose.
Per project style: comments should be one line max and only when the WHY is non-obvious.
Action: trim to a single line or remove if self-explanatory.

---

## Not deviations (confirmed intentional)

- `_HeroImage` uses `BoxFit.fitWidth` — correct after PR #34.
- Categories capped at 8 — correct after PR #34.
- "Подробнее" chip is a Flutter widget overlay — correct, not drawn into image.
- `AppColors.background` == `AppColors.purpleSoft` (same hex `#EDE8FA`) — intentional, scaffold uses lavender.
