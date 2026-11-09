# Design Tokens — YokoMarket
*Source: `lib/theme/app_theme.dart` — verified 2026-11-09*

## Colors — `AppColors`

| Token | Hex | Semantic use |
|---|---|---|
| `background` | `#EDE8FA` | Scaffold / page background (lavender) |
| `surface` | `#FFFFFF` | Cards, bottom sheets, nav bar |
| `lavenderDeep` | `#D6CCEF` | Deeper lavender accent |
| `lavenderMid` | `#D8D0F0` | Mid lavender — skeleton base, loading placeholder |
| `navy` | `#202039` | Primary text |
| `navyMuted` | `#66637A` | Secondary / hint / caption text |
| `purple` | `#6D35D4` | Brand primary — CTAs, selected states, active icons |
| `purpleDark` | `#5428AB` | Pressed / hover purple |
| `purpleSoft` | `#EDE8FA` | Purple tint — nav indicator, category tile bg, chip bg |
| `purpleDisabled` | `#C2A8E8` | Disabled button background |
| `yellow` | `#FFD84F` | Logo badge, cart count badge bg |
| `yellowSoft` | `#FFF8D6` | Soft yellow — warning/info banners |
| `border` | `#EEECF3` | Dividers, card borders |
| `success` | `#1B7F5E` | Success states, stock "В наличии" |
| `error` | `#D92D2D` | Error text, error border |

**Rule:** never hardcode hex in widget files. Use `AppColors.*` tokens only.

## Typography — `NunitoSans`

Font family: **`NunitoSans`** (set globally in `AppTheme`). Never override `fontFamily` inside a widget.
Covers: Russian, Kazakh, `₸` symbol.

| Role | `textTheme` key | Weight | Size |
|---|---|---|---|
| Screen / AppBar title | `headlineSmall` | w700 | ~24 |
| Section header | `titleLarge` | w700 | 16 (overridden) |
| Card title / price | `titleMedium` | w600 | ~16 |
| Sub-label | `titleSmall` | w600 | ~14 |
| Body copy | `bodyMedium` | w400 | ~14 |
| Caption / hint | `bodySmall` | w400 | 13 |
| Button label | `labelLarge` | w700 | ~14 |

AppBar title style: `NunitoSans, 24px, w800` (overridden in `AppBarTheme`).

**All text inside a `Row` must be wrapped in `Flexible`, `Expanded`, or `ConstrainedBox(maxWidth:…)` — never unbounded.**
Do not disable text scaling (`textScaleFactor`) to match a mockup.

## Spacing — `AppSpacing`

| Token | dp | Typical use |
|---|---|---|
| `xs` | 4 | Tight inline gaps (icon–label) |
| `sm` | 8 | Small gaps between related elements |
| `md` | 12 | Inner card padding, compact sections |
| `lg` | 16 | Standard horizontal page margin, section padding |
| `xl` | 20 | Between content sections |
| `x2l` | 24 | Between major screen sections |
| `x3l` | 32 | Large vertical breathing room |
| `screenH` | 20 | Horizontal screen padding (`screenPadding` EdgeInsets) |

## Border Radii — `AppRadii`

| Token | dp | Use |
|---|---|---|
| `card` | 20 | Product cards, image containers |
| `button` | 14 | All buttons |
| `input` | 14 | TextFields |
| `chip` | 20 | Chips, badges |
| `image` | 16 | Standalone image containers, category tiles |

Pre-built `BorderRadius` constants: `cardBorder`, `buttonBorder`, `inputBorder`, `chipBorder`, `imageBorder`.

## Motion

- Short, interruptible: ≤ 300 ms for state transitions; ≤ 400 ms for screen-level.
- Respect `MediaQuery.disableAnimations` — skip or snap non-essential animations.
- Skeletons: 1 200 ms opacity pulse (see `Skeleton` widget).
- Intro animation: 2 800 ms (first-launch only), skippable via tap.
- Do not declare a UI "fast" without profile/release measurements.
