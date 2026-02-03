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
    // 使用 ListenableBuilder 监听 AppService 的变化
    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Nexus',
          debugShowCheckedModeBanner: false,
          
          // --- 亮色主题配置 ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1), // 你的主题色
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC), // 浅灰背景，类似 TuneFree
          ),
          
          // --- 深色主题配置 ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A), // 深色背景
          ),
          
          // --- 绑定全局 ThemeMode ---
          themeMode: AppService().themeMode, 
          
          home: const LandingPage(),
        );
      },
    );
  }
}