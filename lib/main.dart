import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/market_provider.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const YokoMarketApp());
}

class YokoMarketApp extends StatelessWidget {
  const YokoMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarketProvider(),
      child: MaterialApp(
        title: 'YokoMarket',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750F5),
            brightness: Brightness.light,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFFAF9FF),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.light,
        home: const MainScreen(),
      ),
    );
  }
}
