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

  // ✅ 注意：把 IP 改成你 Ubuntu VM 的 IP
  // 你现在代码里是 192.168.159.128，看起来就是 VM IP
  final String baseUrl = "http://192.168.159.128:8080/api";

  User? _currentUser;
  String? _passwordInMemory; // 仅用于演示：发布文章/提升权限时传给后端校验
  String? _lastError;

  bool get isLoggedIn => _currentUser != null;
  User? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == "admin";
  String? get lastError => _lastError;

  void _setError(String? msg) {
    _lastError = msg;
    notifyListeners();
  }

  // 主题
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // -----------------------
  // 登录
  // POST /api/login {email,password}
  // -----------------------
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.trim(), "password": password.trim()}),
      );

      final decoded = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(decoded);
        if (data['status'] == 'success') {
          _currentUser = User(
            name: data['name'] ?? "User",
            email: data['email'] ?? email.trim(),
            role: data['role'] ?? "user",
          );
          _passwordInMemory = password.trim();
          _setError(null);
          return true;
        }
        _setError(data['message'] ?? "登录失败");
        return false;
      }

      if (response.statusCode == 401) {
        _setError("账号或密码错误");
        return false;
      }

      _setError("登录失败：${response.statusCode} $decoded");
      return false;
    } catch (e) {
      _setError("网络错误：$e");
      return false;
    }
  }

  // -----------------------
  // 注册
  // POST /api/register {name,email,password}
  // 服务器强制 role=user
  // -----------------------
  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name.trim(),
          "email": email.trim(),
          "password": password.trim(),
        }),
      );

      final decoded = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(decoded);
        if (data['status'] == 'success') {
          _currentUser = User(
            name: data['name'] ?? name.trim(),
            email: data['email'] ?? email.trim(),
            role: data['role'] ?? "user",
          );
          _passwordInMemory = password.trim();
          _setError(null);
          return true;
        }
        _setError(data['message'] ?? "注册失败");
        return false;
      }

      if (response.statusCode == 409) {
        _setError("该邮箱已注册");
        return false;
      }

      _setError("注册失败：${response.statusCode} $decoded");
      return false;
    } catch (e) {
      _setError("网络错误：$e");
      return false;
    }
  }

  // -----------------------
  // 管理员提升用户为 admin
  // POST /api/admin/promote {adminEmail, adminPassword, targetEmail}
  // -----------------------
  Future<bool> promoteToAdmin(String targetEmail) async {
    if (!isAdmin || _currentUser == null || _passwordInMemory == null) {
      _setError("权限不足：请用管理员账号登录");
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/promote'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "adminEmail": _currentUser!.email,
          "adminPassword": _passwordInMemory,
          "targetEmail": targetEmail.trim(),
        }),
      );

      final decoded = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        _setError(null);
        return true;
      }

      // 返回体里有 message 就显示
      try {
        final data = jsonDecode(decoded);
        _setError(data['message'] ?? "提升失败：${response.statusCode}");
      } catch (_) {
        _setError("提升失败：${response.statusCode} $decoded");
      }
      return false;
    } catch (e) {
      _setError("网络错误：$e");
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _passwordInMemory = null;
    _setError(null);
  }

  // 给文章服务读取凭证（仅演示）
  String? get _emailForAuth => _currentUser?.email;
  String? get _pwdForAuth => _passwordInMemory;
}

// ===========================
// 3. 专门处理文章数据的服务
// ===========================

class MockService {
  final String baseUrl = AppService().baseUrl;

  // 获取文章列表（utf8 解码，避免乱码）
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

  // 发布/更新文章：后端要求 email/password 必须是 admin
  Future<bool> publishArticle(String title, String content, String? id) async {
    try {
      final app = AppService();
      final user = app.currentUser;
      if (user == null) return false;

      final email = app._emailForAuth;
      final pwd = app._pwdForAuth;
      if (email == null || pwd == null) return false;

      final body = {
        "title": title,
        "content": content,
        "author": user.name,
        "email": email,
        "password": pwd,
        if (id != null) "id": id,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/articles/publish'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) return true;

      debugPrint("❌ Publish Failed: ${response.statusCode} ${utf8.decode(response.bodyBytes)}");
      return false;
    } catch (e) {
      debugPrint("❌ Publish Error: $e");
      return false;
    }
  }
}
