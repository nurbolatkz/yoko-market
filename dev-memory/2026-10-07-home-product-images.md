# Home product images

- Problem: Home popular-product cards always showed a static inventory icon and never read `Product.imageUrl`.
- Fix: Added a shared `ProductImage` widget and used it in both Home and Catalog cards.
- Network images use `BoxFit.contain`, show a progress indicator while loading, and show `Фото скоро` only for an empty URL or load error.
- Backend, navigation, card dimensions, and cart behavior were not changed.
