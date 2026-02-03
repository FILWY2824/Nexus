// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/landing_page.dart';
import 'services/mock_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Nexus',
          debugShowCheckedModeBanner: false,
          
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            // 【核心美化】定义更现代的配色和字体基础
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1), // 靛蓝
              surface: const Color(0xFFF8FAFC),   // 极淡的灰背景，比纯白更护眼
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            // 【核心美化】全局字体调整
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontSize: 15, height: 1.5), // 正文稍大，行高增加
              titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.dark,
              surface: const Color(0xFF0F172A), // 深空蓝背景
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
             textTheme: const TextTheme(
              bodyMedium: TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
          
          themeMode: AppService().themeMode, 
          home: const LandingPage(),
        );
      },
    );
  }
}