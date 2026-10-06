# Home screen scrolling

Date: 2026-10-07

## Problem

The Home product grid was a shrink-wrapped `GridView` nested inside a
`SliverList`, creating a second vertical viewport boundary and making the end
of the page unreliable to reach on small phones.

## Fix

Moved the products into a `SliverGrid` owned by the Home `CustomScrollView`, so
the header, banners, categories, brands, promotion, and products share one
scroll position. Added trailing space above the fixed bottom navigation.

## Project structure affected

- `lib/screens/catalog_screen.dart` — unified Home sliver layout
- `test/widget_test.dart` — small-phone bidirectional swipe coverage

## Changes

- Removed the nested vertical `GridView` and its shrink-wrap configuration.
- Added a native `SliverGrid` and 96 logical pixels of bottom clearance.
- Preserved all visuals, navigation, Provider state, and product interactions.

## Verification

- At 320 x 568, swipe tests reached the final Aura product and returned to the
  header without overflow.
- All widget tests passed.
- `flutter analyze` retained only eight existing `withOpacity` notices in
  unchanged screens.

