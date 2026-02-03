// lib/pages/gpt_page.dart

import 'package:flutter/material.dart';
// 如果你已经添加了 http 依赖，取消下面这行的注释
// import 'package:http/http.dart' as http;
// import 'dart:convert';

/// GPT 团队邀请页面
class GptInvitePage extends StatefulWidget {
  const GptInvitePage({super.key});

  @override
  State<GptInvitePage> createState() => _GptInvitePageState();
}

class _GptInvitePageState extends State<GptInvitePage> {
  // 文本控制器，用于获取用户输入的邮箱
  final TextEditingController _emailController = TextEditingController();
  
  // 状态变量：是否正在发送请求
  bool _isLoading = false;

  /// 处理邀请逻辑
  Future<void> _handleInvite() async {
    final email = _emailController.text.trim();

    // 1. 简单的本地校验
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('请输入有效的邮箱地址', isError: true);
      return;
    }

    setState(() {
      _isLoading = true; // 显示加载转圈
    });

    try {
      // ==========================================================
      // TODO: 对接你的 Python 后端 (Cloudflare Tunnel)
      // ==========================================================
      
      // 示例代码：
      /*
      final url = Uri.parse('https://api.yourdomain.com/invite_member');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('成功：已向 $email 发送 GPT 团队邀请！');
        _emailController.clear(); // 清空输入框
      } else {
        _showSnackBar('失败：${response.body}', isError: true);
      }
      */

      // --- 模拟网络请求 (调试用) ---
      await Future.delayed(const Duration(seconds: 2)); // 模拟延时
      
      // 模拟成功
      if (mounted) {
        _showSnackBar('已向 $email 发送 GPT 团队邀请！(模拟成功)');
        _emailController.clear();
      }

    } catch (e) {
      if (mounted) {
        _showSnackBar('网络请求出错: $e', isError: true);
      }
    } finally {
      // 无论成功失败，都停止加载状态
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 封装一个简单的提示条
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating, // 悬浮样式
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose(); // 销毁控制器，释放内存
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 居中布局，限制最大宽度，适配宽屏
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 2, // 卡片阴影
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 高度自适应
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题区
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    // 使用 smart_toy (智能玩具/机器人) 代替
                    child: const Icon(Icons.smart_toy_outlined, size: 32, color: Colors.green),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GPT 团队邀请",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "自动化添加成员至 ChatGPT Team",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // 输入区
                const Text("成员邮箱", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: "example@gmail.com",
                    prefixIcon: Icon(Icons.email_outlined),
                    helperText: "系统将通过后端 Python 脚本自动执行拉人操作",
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _handleInvite(), // 回车直接提交
                ),

                const SizedBox(height: 32),

                // 按钮区
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleInvite,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send),
                              SizedBox(width: 8),
                              Text("发送邀请", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}