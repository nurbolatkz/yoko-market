# Remove opacity deprecations

Date: 2026-10-07

## Problem

`flutter analyze` reported eight deprecated `Color.withOpacity` calls.

## Fix

Replaced each call with the equivalent `Color.withValues(alpha: ...)` while
preserving the exact opacity values and visual output.

## Project structure affected

- `lib/screens/cart_screen.dart`
- `lib/screens/product_detail_screen.dart`
- `lib/screens/profile_screen.dart`

## Changes

- Updated eight deprecated color operations without changing layout or logic.

## Verification

- `flutter analyze` completed with `No issues found`.
- All five tests passed.

