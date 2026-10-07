# Django catalog API

Date: 2026-10-07

## Problem

The Catalog still used local mock products and could not represent real Django
IDs, prices, images, categories, or stock availability.

## Fix

Added a configurable Dio-based read-only catalog datasource and moved Catalog
loading into the existing `MarketProvider`, with explicit loading, error/retry,
empty, and data states.

## Project structure affected

- `lib/config/app_config.dart` — `API_BASE` build-time configuration
- `lib/services/catalog_api.dart` — Django catalog GET requests
- `lib/models/product.dart` — confirmed API field parsing and image URLs
- `lib/models/product_category.dart` — category response model
- `lib/providers/market_provider.dart` — asynchronous catalog state
- `lib/screens/product_catalog_screen.dart` — API state UI and remote filtering
- `android/app/src/main/AndroidManifest.xml` — release network permission
- `test/widget_test.dart` — fake datasource and response parser coverage

## Changes

- Connected `GET /products` with `category`, `search`, `sort`, `limit`, `offset`.
- Connected `GET /categories/public` and flattened nested categories.
- Removed catalog fallback mocks; errors remain visible with a retry action.
- Added availability display and disabled cart addition for unavailable products.
- Kept Provider, existing Catalog visuals, favorites, cart, and detail navigation.

## Verification

- Both public endpoints returned HTTP 200 using read-only GET requests.
- Product JSON fields were checked against a live one-item response.
- Tests used an injected fake datasource and did not mutate production data.
- Five tests passed; `flutter analyze` retained only eight existing deprecations
  in unchanged screens.

