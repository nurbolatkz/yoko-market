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
