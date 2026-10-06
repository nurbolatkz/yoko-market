# Home screen visuals

Date: 2026-10-07

## Problem

The Home screen used placeholder banner graphics and did not closely match the
provided branded Home reference.

## Fix

Copied the two standalone banner images into Flutter assets and rebuilt only
the Home presentation with responsive native text overlays.

## Project structure affected

- `assets/images/` — hero and promotion banner backgrounds
- `lib/screens/catalog_screen.dart` — Home screen presentation and interactions
- `pubspec.yaml` — Flutter asset registration
- `test/widget_test.dart` — small-phone overflow coverage

## Changes

- Added `hero_banner.png` and `promotion_banner.png` without using screenshots.
- Kept banner text native, left-aligned, and product imagery visible at right.
- Improved category label readability and retained the existing section order.
- Preserved search, product navigation, add-to-cart behavior, Provider, and tabs.
- Audited tracked source files; all are referenced, so no working demo source
  files were removed. No standalone category or product assets were available.

## Verification

- `flutter analyze` reported only eight existing `withOpacity` deprecations in
  unchanged Cart, Product Detail, and Profile screens.
- Widget tests passed, including a 320 x 568 overflow check.

