// lib/services/mock_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
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
      title: (json['title'] ?? '无标题').toString(),
      summary: (json['summary'] ?? '').toString(),
      author: (json['author'] ?? 'Unknown').toString(),
      publishDate: json['publishDate'] != null
          ? (DateTime.tryParse(json['publishDate'].toString()) ?? DateTime.now())
          : DateTime.now(),
      views: json['views'] is int ? json['views'] as int : int.tryParse(json['views'].toString()) ?? 0,
      content: (json['content'] ?? '').toString(),
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

  /// ✅ Cloudflare Tunnel 后端（不再使用内网 IP / 端口）
  /// 你可以后续只改这一行。
  final String baseUrl = 'https://backendapi.officecy.dpdns.org/api';

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';

  /// 用于“需要鉴权的接口”（例如 updateProfile / promote / publish 等）
  /// 目前你的后端是 email+password 校验，所以前端临时保存一份。
  /// （真正安全的做法是后端发 token/session；后续你要做我也能帮你改。）
  String? _passwordInMemory;

  /// 用户资料（设置页会用）
  String _bio = '';
  String get bio => _bio;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;

  /// UI 错误提示
  String? _lastError;
  String? get lastError => _lastError;

  void _setError(String? msg) {
    _lastError = msg;
    notifyListeners();
  }

  // ---------- 主题 / 偏好（UserPage 用到） ----------

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

  // ---------- API：登录 / 注册 / 退出 ----------

  Future<bool> login(String email, String password) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = utf8.decode(resp.bodyBytes);

      if (resp.statusCode == 200) {
        final data = jsonDecode(decoded);
        if (data['status'] == 'success') {
          _currentUser = User(
            name: (data['name'] ?? 'User').toString(),
            email: (data['email'] ?? email.trim()).toString(),
            role: (data['role'] ?? 'user').toString(),
          );

          if (data.containsKey('bio')) _bio = (data['bio'] ?? '').toString();
          if (data.containsKey('updated_at')) {
            final s = (data['updated_at'] ?? '').toString();
            _updatedAt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
          }

          _passwordInMemory = password.trim();
          _setError(null);
          return true;
        }
        _setError((data['message'] ?? '登录失败').toString());
        return false;
      }

      _setError('登录失败：${resp.statusCode} $decoded');
      return false;
    } catch (e) {
      _setError('网络错误：$e');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'email': email.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = utf8.decode(resp.bodyBytes);

      if (resp.statusCode == 200) {
        final data = jsonDecode(decoded);
        if (data['status'] == 'success') {
          _currentUser = User(
            name: (data['name'] ?? name.trim()).toString(),
            email: (data['email'] ?? email.trim()).toString(),
            role: (data['role'] ?? 'user').toString(),
          );

          if (data.containsKey('bio')) _bio = (data['bio'] ?? '').toString();
          if (data.containsKey('updated_at')) {
            final s = (data['updated_at'] ?? '').toString();
            _updatedAt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
          }

          _passwordInMemory = password.trim();
          _setError(null);
          return true;
        }
        _setError((data['message'] ?? '注册失败').toString());
        return false;
      }

      _setError('注册失败：${resp.statusCode} $decoded');
      return false;
    } catch (e) {
      _setError('网络错误：$e');
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _passwordInMemory = null;
    _bio = '';
    _updatedAt = null;
    _setError(null);
  }

  // ---------- API：更新资料（UserPage 用到） ----------

  Future<bool> updateProfileRemote({required String name, required String bio}) async {
    if (_currentUser == null || _passwordInMemory == null) {
      _setError('未登录');
      return false;
    }

    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/user/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _currentUser!.email,
              'password': _passwordInMemory,
              'name': name.trim(),
              'bio': bio.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

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

          final s = (data['updated_at'] ?? '').toString();
          _updatedAt = DateTime.tryParse(s.replaceFirst(' ', 'T'));

          _setError(null);
          return true;
        }
        _setError((data['message'] ?? '更新失败').toString());
        return false;
      }

      _setError('更新失败：${resp.statusCode} $decoded');
      return false;
    } catch (e) {
      _setError('网络错误：$e');
      return false;
    }
  }

  // ---------- API：管理员提升权限（BlogPage/其他地方可能用到） ----------

  Future<bool> promoteToAdmin(String targetEmail) async {
    if (_currentUser == null || _passwordInMemory == null) {
      _setError('未登录');
      return false;
    }
    if (!isAdmin) {
      _setError('权限不足：需要管理员账号');
      return false;
    }

    Future<http.Response> _post(String path) {
      return http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adminEmail': _currentUser!.email,
          'adminPassword': _passwordInMemory,
          'targetEmail': targetEmail.trim(),
        }),
      );
    }

    try {
      // 兼容你可能的两种路由：/admin/promote 或 /promote
      http.Response resp = await _post('/admin/promote').timeout(const Duration(seconds: 12));
      if (resp.statusCode == 404) {
        resp = await _post('/promote').timeout(const Duration(seconds: 12));
      }

      final decoded = utf8.decode(resp.bodyBytes);

      if (resp.statusCode == 200) {
        _setError(null);
        return true;
      }

      try {
        final data = jsonDecode(decoded);
        _setError((data['message'] ?? '提升失败').toString());
      } catch (_) {
        _setError('提升失败：${resp.statusCode} $decoded');
      }
      return false;
    } catch (e) {
      _setError('网络错误：$e');
      return false;
    }
  }

  // ---------- URL helpers (for images / attachments) ----------

  /// Your API baseUrl ends with `/api`. Many media resources are served outside
  /// that prefix (e.g. `/uploads/...`).
  ///
  /// This returns the origin part so we can resolve relative URLs safely.
  String get origin {
    // Keep it simple: remove the trailing `/api` if present.
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(0, baseUrl.length - 4);
    }
    return baseUrl;
  }

  /// Resolve a potentially-relative media URL into an absolute URL.
  ///
  /// - Already absolute: returned as-is.
  /// - Starts with `/`: prefixed with [origin].
  /// - Otherwise: `${origin}/$url`.
  String resolveMediaUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/')) return '$origin$u';
    return '$origin/$u';
  }
}

// ===========================
// 3. 文章服务
// ===========================

class MockService {
  final String baseUrl = AppService().baseUrl;

  Future<List<Article>> getArticles() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/articles')).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = utf8.decode(resp.bodyBytes);
        final list = jsonDecode(decoded) as List<dynamic>;
        return list.map((j) => Article.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('❌ Get Articles Error: $e');
    }
    return [];
  }

  /// Fetch a single article with full `content`.
  /// Backend: GET /api/articles/<id>
  Future<Article?> getArticleById(String id) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/articles/$id'))
          .timeout(const Duration(seconds: 12));

      final decoded = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final map = jsonDecode(decoded) as Map<String, dynamic>;
        return Article.fromJson(map);
      }

      debugPrint('❌ Get Article Failed: ${resp.statusCode} $decoded');
      return null;
    } catch (e) {
      debugPrint('❌ Get Article Error: $e');
      return null;
    }
  }

  Future<bool> publishArticle(String title, String content, String? id) async {
    try {
      final app = AppService();
      final user = app.currentUser;
      if (user == null) {
        app._setError('未登录');
        return false;
      }

      final body = <String, dynamic>{
        'title': title,
        'content': content,
        'author': user.name,
        if (id != null) 'id': id,
      };

      // 如果你的后端 publish 需要鉴权，可自动带上 email/password
      if (app.currentUser != null && app._passwordInMemory != null) {
        body['email'] = app.currentUser!.email;
        body['password'] = app._passwordInMemory;
      }

      final resp = await http
          .post(
            Uri.parse('$baseUrl/articles/publish'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = utf8.decode(resp.bodyBytes);

      if (resp.statusCode == 200) {
        app._setError(null);
        return true;
      }

      // Try best-effort to parse server message.
      try {
        final data = jsonDecode(decoded);
        app._setError((data['message'] ?? '发布失败').toString());
      } catch (_) {
        app._setError('发布失败：${resp.statusCode} $decoded');
      }

      debugPrint('❌ Publish Failed: ${resp.statusCode} $decoded');
      return false;
    } catch (e) {
      final app = AppService();
      app._setError('网络错误：$e');
      debugPrint('❌ Publish Error: $e');
      return false;
    }
  }

  // 添加在 publishArticle 方法下方
  Future<bool> deleteArticle(String id) async {
    try {
      final app = AppService();
      
      // 1. 检查是否登录
      if (app.currentUser == null || app._passwordInMemory == null) {
        debugPrint('❌ Delete Failed: Not logged in');
        return false;
      }

      // 2. 发送带凭据的请求
      final resp = await http.post(
        Uri.parse('$baseUrl/articles/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'email': app.currentUser!.email,       // ✅ 使用真实当前用户邮箱
          'password': app._passwordInMemory,     // ✅ 使用真实内存中保存的密码
        }),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        return true;
      }

      debugPrint('❌ Delete Failed: ${resp.statusCode} ${utf8.decode(resp.bodyBytes)}');
      return false;
    } catch (e) {
      debugPrint('❌ Delete Error: $e');
      return false;
    }
  }
}
