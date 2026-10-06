# Catalog card imagery and readability

Date: 2026-10-07

## Problem

Catalog products used unrelated stock photos, repeated size details in titles,
and displayed small product text.

## Fix

Removed remote stock URLs and added a contained, neutral “Фото скоро” image
state because no standalone product assets are present in the project.

## Project structure affected

- `lib/providers/market_provider.dart` — concise product names and no stock URLs
- `lib/screens/product_catalog_screen.dart` — contained imagery and readable cards
- `test/widget_test.dart` — placeholder and small-phone coverage

## Changes

- Product names now exclude size and package details.
- Package information appears once in its own two-line field.
- Increased name and package typography and card height.
- Kept price rows and add buttons aligned with flexible card spacing.
- Future local asset paths render with `BoxFit.contain` without cropping.

## Verification

- The only available image assets are the Home hero and promotion banners; no
  matching standalone product images were available.
- All widget tests passed at the 320 x 568 small-phone viewport.
- `flutter analyze` retained only eight existing deprecation notices in
  unchanged screens.

