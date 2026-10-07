# Catalog pagination, subcategory filter fix, and backend is_active guard

Date: 2026-10-07

## Problem

Three issues blocked a correct live-catalog integration:

1. `GET /products` without `X-Telegram-Init-Data` or a manager Bearer token returned
   all products including inactive/unpriced ones — no `is_active` guard for public access.
2. `getCategories()` flattened subcategories into the filter chip list. Their names are
   stored in `Product.subcategory`, not `Product.category`, so passing a subcategory name
   as `?category=` produced zero results.
3. Catalog was capped at the first 100 items; there was no load-more path.

## Fix

- **Backend** (`bot/api/routers/products.py`): added an `authorization` header check to
  `list_products`. Requests that carry no initData and no valid manager JWT now receive an
  implicit `is_active=True` and `price > 0` filter. Dashboard managers (Bearer manager
  JWT) keep the existing unfiltered view. Telegram Mini App (initData) is unchanged.
- **Flutter** (`lib/services/catalog_api.dart`): `getCategories()` now maps the top-level
  category array directly without expanding subcategories. Removed `_flattenCategoryMaps`.
- **Flutter** (`lib/providers/market_provider.dart`): added `_pageSize = 50`,
  `_loadedOffset`, `_hasMore`, `_isLoadingMore` state. `loadCatalog()` and `loadProducts()`
  reset the offset and set `_hasMore = (page.length == _pageSize)`. New `loadMoreProducts()`
  appends the next page, guarded by a `_requestVersion` snapshot so a concurrent
  filter/search change discards stale results.
- **Flutter** (`lib/screens/product_catalog_screen.dart`): replaced `GridView.builder`
  with `RefreshIndicator` → `CustomScrollView` + `SliverGrid`. Added `ScrollController`
  that calls `loadMoreProducts()` when the user scrolls within 300 px of the end. A
  `SliverToBoxAdapter` spinner appears below the grid while `isLoadingMore` is true.
  Pull-to-refresh calls `loadCatalog()`.

## Project structure affected

- `lib/services/catalog_api.dart` — removed subcategory flattening; `limit` default → 50
- `lib/providers/market_provider.dart` — pagination state and `loadMoreProducts()`
- `lib/screens/product_catalog_screen.dart` — infinite scroll and pull-to-refresh
- `test/widget_test.dart` — fake datasource `limit` default updated to match interface
- `../telegram-mini-app/bot/api/routers/products.py` — public `is_active` guard

## Changes

- Backend: `decode_token` added to imports; `list_products` accepts `authorization` header
  and applies `is_active`/`price > 0` for unauthenticated callers only.
- Removed `_flattenCategoryMaps` function from `catalog_api.dart`.
- `MarketProvider`: `_pageSize = 50`, `_loadedOffset`, `_hasMore`, `_isLoadingMore`;
  updated `loadCatalog()` and `loadProducts()`; added `loadMoreProducts()`.
- `ProductCatalogScreen`: `ScrollController`, `RefreshIndicator`, `CustomScrollView`,
  `SliverGrid`, load-more spinner, LinearProgressIndicator overlay preserved.

## Verification

- Backend change: verified by code review — `is_active` and `price > 0` filters applied
  at `products.py:366-367` for callers without bot_brands and without manager token.
- Subcategory fix: confirmed `Product.category` stores top-level names only (e.g.
  "Подгузники"), while subcategory names (e.g. "Premium Подгузники") are in
  `Product.subcategory` — passing subcategory name as `?category=` returned 0 results.
- Flutter: `flutter analyze` and `flutter test` could not be run (Flutter not installed
  on the server). Code reviewed manually for type safety and interface conformance.
- Existing widget tests expect 8 products from `_FakeCatalogDataSource`; with
  `_pageSize = 50` the fake returns all 8 on the first page → `hasMore = false`,
  test expectations unchanged.
