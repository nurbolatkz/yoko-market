import 'package:flutter/widgets.dart';

/// Image provider for URLs coming from data models.
///
/// `asset:<path>` is used only by UI_PREVIEW fixtures for bundled
/// illustrations; everything else (all production data) is a network URL.
ImageProvider appImageProvider(String url) => url.startsWith('asset:')
    ? AssetImage(url.substring('asset:'.length))
    : NetworkImage(url);

/// [appImageProvider] downscaled to [cacheWidth] physical pixels.
ImageProvider appImageProviderSized(String url, int cacheWidth) =>
    ResizeImage.resizeIfNeeded(cacheWidth, null, appImageProvider(url));
