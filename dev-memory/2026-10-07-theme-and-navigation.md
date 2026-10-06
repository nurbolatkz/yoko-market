# Theme and bottom navigation

Date: 2026-10-07

## Problem

Theme values and navigation colors were defined directly in widgets, making
the purple/yellow design inconsistent and difficult to reuse.

## Fix

Added a shared light theme and moved the five-tab bottom navigation onto the
theme, with safe-area handling for iOS and Android.

## Project structure affected

- `lib/theme/app_theme.dart` — shared colors, typography, buttons, inputs,
  rounded cards, badges, and navigation styling
- `lib/main.dart` — applies the shared application theme
- `lib/screens/main_screen.dart` — themed, safe-area bottom navigation

## Changes

- Added navy text, purple primary actions, yellow accents, and a light surface.
- Added reusable card and control radii.
- Kept the five tabs: Главная, Каталог, Корзина, Избранное, Профиль.
- Preserved the existing screens, indexed navigation, cart badge, and Provider.

## Verification

- `flutter analyze` completed with only eight pre-existing `withOpacity`
  deprecation notices in unchanged screen files.

