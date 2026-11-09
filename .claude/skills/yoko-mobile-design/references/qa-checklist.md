# QA Checklist — YokoMarket UI
*Run before marking any UI task complete.*

## Code quality

- [ ] `flutter analyze --no-pub` → zero errors (warnings from pre-existing test files are acceptable if unchanged)
- [ ] Zero hardcoded hex colors in widget files — all use `AppColors.*`
- [ ] Zero inline `fontFamily` overrides — all use `AppTheme` / `NunitoSans` via theme
- [ ] No unbounded `Text` in a `Row` — each wrapped in `Flexible`, `Expanded`, or `ConstrainedBox`
- [ ] No new pub dependencies added without explicit necessity

## States

- [ ] Every async data source has loading, error, and empty states
- [ ] Loading: `Skeleton` widget with matching layout dimensions (no reflow)
- [ ] Error: message + "Повторить" button
- [ ] Empty: icon + bodyMedium description
- [ ] Disabled buttons use `onPressed: null` — not color overrides

## Layout and text scaling

- [ ] Layout correct at 360 dp width
- [ ] Layout correct at 390 dp width
- [ ] No overflow at `textScaleFactor` 1.5×
- [ ] Long Russian / Kazakh text does not clip or overflow
- [ ] Category tile labels wrap gracefully at large text scale (no clipping)
- [ ] `SafeArea` applied on screens that touch status/nav bar edges

## Images

- [ ] Banners use `LayoutBuilder` + `devicePixelRatioOf` for `cacheWidth` (clamped 800–2048)
- [ ] Product images use `ProductImage` widget — no inline `Image.network` duplication
- [ ] All `Image.network` calls have `errorBuilder`
- [ ] Hero images use `BoxFit.fitWidth` or `BoxFit.contain` — not `BoxFit.cover` on variable-ratio images

## Accessibility

- [ ] Interactive elements without visible text have `Semantics(label: ...)` 
- [ ] Color contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text (WCAG 2.2 AA)
- [ ] Tap targets ≥ 48 × 48 dp
- [ ] `MediaQuery.disableAnimations` checked for non-essential animations

## Business logic

- [ ] No invented prices, stock numbers, discounts, or delivery times
- [ ] No non-functional buttons
- [ ] API contracts unchanged
- [ ] Auth / cart / wishlist state unaffected by UI changes
- [ ] Missing assets listed explicitly (not substituted with placeholder)

## Platform behaviour

- [ ] Back navigation works on Android (system back gesture)
- [ ] Keyboard does not cover active `TextField` (use `resizeToAvoidBottomInset`)
- [ ] Bottom nav bar not obscured by system nav bar (SafeArea)
- [ ] No fake system status/nav bar images

## Before / after

- [ ] Screenshot or ASCII diff provided for non-trivial visual changes
- [ ] Distinguish "app launched" vs "read code" in task summary
