// lib/services/mock_service.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// ===========================
/// 1. 数据模型
/// ===========================

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

/// ===========================
/// 2. 全局状态与 API 服务
/// ===========================

class AppService extends ChangeNotifier {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  /// ✅ 改为 HTTPS + 新端口
  /// 注意：Flutter Web 使用浏览器网络栈，自签名证书需要先在浏览器里“继续访问/信任一次”
  /// 你可以先打开：https://192.168.159.128:8443/api/articles 通过证书提示。
  final String baseUrl = "https://192.168.159.128:8443/api";

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == "admin";

  /// 主题
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// 偏好（可选：给设置页用；不用也不影响）
  bool _denseMode = false;
  bool get denseMode => _denseMode;
  void setDenseMode(bool v) {
    _denseMode = v;
    notifyListeners();
  }

  bool _reduceMotion = false;
  bool get reduceMotion => _reduceMotion;
  void setReduceMotion(bool v) {
    _reduceMotion = v;
    notifyListeners();
  }

  /// 用户资料（可选：与你的 /api/user/update 兼容）
  String _bio = "";
  String get bio => _bio;
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;

  /// 错误信息（便于 UI 显示）
  String? _lastError;
  String? get lastError => _lastError;

  /// ⚠️ 兼容你当前后端：部分接口仍需要 email/password 鉴权
  String? _passwordInMemory;

  void _setError(String? msg) {
    _lastError = msg;
    notifyListeners();
  }

  String _hintForWebCertIfNeeded(Object e) {
    final s = e.toString();
    // Flutter Web 常见：ClientException: XMLHttpRequest error.
    if (s.contains('XMLHttpRequest') || s.contains('Failed host lookup') || s.contains('HandshakeException')) {
      return "网络错误（HTTPS 证书可能未信任）。请先在浏览器打开并继续访问："
          "https://192.168.159.128:8443/api/articles";
    }
    return "网络错误：$s";
  }

  /// 登录 (连接后端)
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
            name: (data['name'] ?? "User").toString(),
            email: (data['email'] ?? email.trim()).toString(),
            role: (data['role'] ?? "user").toString(),
          );

          // 可选字段（后端有返回就同步）
          if (data.containsKey('bio')) _bio = (data['bio'] ?? "").toString();
          if (data.containsKey('updated_at')) {
            final s = (data['updated_at'] ?? "").toString();
            // 后端是 "YYYY-MM-DD HH:mm:ss"，这里兼容解析
            _updatedAt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
          }

          _passwordInMemory = password.trim();
          _setError(null);
          return true;
        }
        _setError((data['message'] ?? "登录失败").toString());
        return false;
      }

      _setError("登录失败：${response.statusCode} $decoded");
      return false;
    } catch (e) {
      _setError(_hintForWebCertIfNeeded(e));
      return false;
    }
  }

  /// 注册（后端默认 role=user）
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
            name: (data['name'] ?? name.trim()).toString(),
            email: (data['email'] ?? email.trim()).toString(),
            role: (data['role'] ?? "user").toString(),
          );

          if (data.containsKey('bio')) _bio = (data['bio'] ?? "").toString();
          if (data.containsKey('updated_at')) {
            final s = (data['updated_at'] ?? "").toString();
            _updatedAt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
          }

          _passwordInMemory = password.trim();
          _setError(null);
          return true;
        }
        _setError((data['message'] ?? "注册失败").toString());
        return false;
      }

      _setError("注册失败：${response.statusCode} $decoded");
      return false;
    } catch (e) {
      _setError(_hintForWebCertIfNeeded(e));
      return false;
    }
  }

  /// 管理员：提升某个用户为 admin
  Future<bool> promoteToAdmin(String targetEmail) async {
    if (_currentUser == null || _passwordInMemory == null) {
      _setError("未登录");
      return false;
    }
    if (!isAdmin) {
      _setError("权限不足：需要管理员账号");
      return false;
    }

    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/admin/promote'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "adminEmail": _currentUser!.email,
          "adminPassword": _passwordInMemory,
          "targetEmail": targetEmail.trim(),
        }),
      );

      final decoded = utf8.decode(resp.bodyBytes);

      if (resp.statusCode == 200) {
        _setError(null);
        return true;
      }

      // 尝试解析后端 message
      try {
        final data = jsonDecode(decoded);
        _setError((data['message'] ?? "提升失败").toString());
      } catch (_) {
        _setError("提升失败：${resp.statusCode} $decoded");
      }
      return false;
    } catch (e) {
      _setError(_hintForWebCertIfNeeded(e));
      return false;
    }
  }

  /// 退出登录（前端清状态）
  void logout() {
    _currentUser = null;
    _passwordInMemory = null;
    _bio = "";
    _updatedAt = null;
    _setError(null);
  }

  /// （可选）更新个人资料：需要后端已提供 /api/user/update
  Future<bool> updateProfileRemote({required String name, required String bio}) async {
    if (_currentUser == null || _passwordInMemory == null) {
      _setError("未登录");
      return false;
    }
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/user/update'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _currentUser!.email,
          "password": _passwordInMemory,
          "name": name.trim(),
          "bio": bio.trim(),
        }),
      );
      final decoded = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final data = jsonDecode(decoded);
        if (data['status'] == 'success') {
          _currentUser = User(
            name: (data['name'] ?? name).toString(),
            email: _currentUser!.email,
            role: (data['role'] ?? _currentUser!.role).toString(),
          );
          _bio = (data['bio'] ?? bio).toString();
          final s = (data['updated_at'] ?? "").toString();
          _updatedAt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
          _setError(null);
          return true;
        }
        _setError((data['message'] ?? "更新失败").toString());
        return false;
      }
      _setError("更新失败：${resp.statusCode} $decoded");
      return false;
    } catch (e) {
      _setError(_hintForWebCertIfNeeded(e));
      return false;
    }
  }

  String? get _emailForAuth => _currentUser?.email;
  String? get _pwdForAuth => _passwordInMemory;
}

/// ===========================
/// 3. 文章服务
/// ===========================

class MockService {
  final String baseUrl = AppService().baseUrl;

  /// 获取文章列表
  Future<List<Article>> getArticles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/articles'));
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        List<dynamic> list = jsonDecode(decoded);
        return list.map((json) => Article.fromJson(json)).toList();
      } else {
        debugPrint("Get Articles Failed: ${response.statusCode} ${utf8.decode(response.bodyBytes)}");
      }
    } catch (e) {
      debugPrint("❌ Get Articles Error: $e");
    }
    return [];
  }

  /// 发布/更新文章
  Future<bool> publishArticle(String title, String content, String? id) async {
    try {
      final app = AppService();
      final user = app.currentUser;
      if (user == null) return false;

      final body = <String, dynamic>{
        "title": title,
        "content": content,
        "author": user.name,
        if (id != null) "id": id,
      };

      // 如果后端要求鉴权，自动带上 email/password（你现在的后端很多接口是这样设计的）
      final email = app._emailForAuth;
      final pwd = app._pwdForAuth;
      if (email != null && pwd != null) {
        body["email"] = email;
        body["password"] = pwd;
      }

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
