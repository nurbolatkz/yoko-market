import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/market_provider.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const YokoMarketApp());
}

class YokoMarketApp extends StatelessWidget {
  const YokoMarketApp({super.key, this.marketProvider});

  final MarketProvider? marketProvider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (marketProvider ?? MarketProvider())..loadCatalog(),
      child: MaterialApp(
        title: 'YokoMarket',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: const MainScreen(),
      ),
    );
  }
}
