// lib/services/mock_service.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ===========================
// 1. 数据模型
// ===========================

class User {
  final String name;
  final String email;
  final String role; 

  User({required this.name, required this.email, required this.role});
}

class Article {
  final String id;
  final String title;
  final String summary;
  final String author;
  final DateTime publishDate;
  final int views;
  final String content;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.author,
    required this.publishDate,
    required this.views,
    this.content = "",
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'].toString(),
      title: json['title'] ?? "无标题",
      summary: json['summary'] ?? "",
      author: json['author'] ?? "Unknown",
      publishDate: json['publishDate'] != null 
          ? DateTime.tryParse(json['publishDate']) ?? DateTime.now() 
          : DateTime.now(),
      views: json['views'] is int ? json['views'] : int.tryParse(json['views'].toString()) ?? 0,
      content: json['content'] ?? "",
    );
  }
}

// ===========================
// 2. 全局状态与 API 服务
// ===========================

class AppService extends ChangeNotifier {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  // 【注意】Web端测试时，浏览器会拦截跨域请求。
  // 必须确保 C++ 后端配置了 CORS 头，否则这里会报错 XMLHttpRequest error
  final String baseUrl = "http://192.168.159.128:8080/api";

  User? _currentUser;
  bool get isLoggedIn => _currentUser != null;
  User? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == "admin";

  // 【修复 1】补回主题状态变量
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // 【修复 2】补回切换主题方法
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  // 登录 (连接后端)
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        // Web 端发送 JSON 需要设置 Header
        headers: {"Content-Type": "application/json"}, 
        body: jsonEncode({"email": email.trim(), "password": password.trim()}),
      );

      final decoded = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        final data = jsonDecode(decoded);
        if (data['status'] == 'success') {
          _currentUser = User(
            name: data['name'],
            email: email,
            role: data['role'],
          );
          notifyListeners();
          return true;
        }
      } else {
        debugPrint("Login Failed: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Login Network Error: $e");
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}

// 专门处理文章数据的服务
class MockService {
  final String baseUrl = AppService().baseUrl;

  // 获取文章列表
  Future<List<Article>> getArticles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/articles'));
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        List<dynamic> list = jsonDecode(decoded);
        return list.map((json) => Article.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("❌ Get Articles Error: $e");
    }
    return [];
  }

  // 发布/更新文章
  Future<bool> publishArticle(String title, String content, String? id) async {
    try {
      final user = AppService().currentUser;
      if (user == null) return false;

      final body = {
        "title": title,
        "content": content,
        "author": user.name,
        if (id != null) "id": id,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/articles/publish'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Publish Error: $e");
      return false;
    }
  }
}