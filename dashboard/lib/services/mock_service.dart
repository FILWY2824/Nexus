// lib/services/mock_service.dart
import 'package:flutter/material.dart';
import '../models/data_model.dart';

class AppService extends ChangeNotifier {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  // --- 主题控制 (新功能) ---
  ThemeMode _themeMode = ThemeMode.light; // 默认浅色
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // 通知所有界面刷新颜色
  }

  // --- 用户状态 ---
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email == 'admin@linux.do') {
      _currentUser = User(email: email, name: 'Admin User', role: UserRole.admin);
    } else {
      _currentUser = User(email: email, name: 'Guest User', role: UserRole.guest);
    }
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // --- 博客数据 (保持不变) ---
  final List<BlogPost> _posts = [
    BlogPost(id: '1', title: 'Linux 后端优化指南', summary: '探讨内核级性能监控...', author: 'Admin', publishDate: DateTime.now(), views: 1205),
    BlogPost(id: '2', title: 'Flutter 跨平台实战', summary: '从零构建多端应用...', author: 'Admin', publishDate: DateTime.now(), views: 890),
  ];
  List<BlogPost> get posts => _posts;
}