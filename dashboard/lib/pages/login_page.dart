// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/mock_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true; // 切换 登录/注册 视图
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openTrustPage() async {
    final url = Uri.parse('${AppService().baseUrl}/articles');
    await launchUrl(url, mode: LaunchMode.platformDefault);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final app = AppService();
    final email = _emailController.text;
    final password = _passwordController.text;

    bool success;
    if (_isLogin) {
      success = await app.login(email, password);
    } else {
      final name = _nameController.text.isEmpty ? "User" : _nameController.text;
      success = await app.register(name, email, password);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context); // 成功返回
      return;
    }

    _showError(app.lastError ?? "操作失败");
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.hub, size: 64, color: Theme.of(context).primaryColor),
              const SizedBox(height: 28),
              Text(
                _isLogin ? "欢迎回来" : "创建账号",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "后端已启用 HTTPS：${AppService().baseUrl}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 22),

              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "昵称",
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "邮箱",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "密码",
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                obscureText: true,
                onSubmitted: (_) => _isLoading ? null : _submit(),
              ),

              const SizedBox(height: 22),

              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isLogin ? "登录" : "注册账号", style: const TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 12),

              // ✅ 证书信任快捷入口（自签名证书必需）
              TextButton.icon(
                onPressed: _openTrustPage,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text("首次使用：点此打开后端地址并信任证书"),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "没有账号？去注册" : "已有账号？去登录"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
