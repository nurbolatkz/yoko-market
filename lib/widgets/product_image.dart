import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const ProductImagePlaceholder();
    }

    return ColoredBox(
      color: const Color(0xFFF6F4FB),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: imageUrl.startsWith('assets/')
            ? Image.asset(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const ProductImagePlaceholder(),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;

                  final totalBytes = loadingProgress.expectedTotalBytes;
                  final progress = totalBytes == null
                      ? null
                      : loadingProgress.cumulativeBytesLoaded / totalBytes;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.5,
                      color: AppColors.purple,
                    ),
                  );
                },
                errorBuilder: (_, _, _) => const ProductImagePlaceholder(),
              ),
      ),
    );
  }
}

class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1EFF7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, size: 38, color: AppColors.navyMuted),
            SizedBox(height: 6),
            Text(
              'Фото скоро',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navyMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
