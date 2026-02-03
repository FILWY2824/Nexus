// lib/pages/landing_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/mock_service.dart';
import 'dashboard.dart';
import 'login_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  // GitHub 跳转函数
  Future<void> _launchGitHub() async {
    final Uri url = Uri.parse('https://github.com/FILWY2824');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听主题变化
    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              // --- 1. 顶部导航栏 (AppBar) ---
              SliverAppBar(
                floating: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                title: Row(
                  children: [
                    Icon(Icons.hub, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text("Nexus", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                actions: [
                  // GitHub 按钮
                  IconButton(
                    tooltip: "GitHub 仓库",
                    icon: const Icon(Icons.code), // 用 code 图标代表 GitHub
                    color: textColor,
                    onPressed: _launchGitHub, 
                  ),
                  // 主题切换按钮
                  IconButton(
                    tooltip: "切换主题",
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    color: textColor,
                    onPressed: () => AppService().toggleTheme(),
                  ),
                  const SizedBox(width: 8),
                  // 登录/注册按钮
                  if (!AppService().isLoggedIn)
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: OutlinedButton(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                        },
                        child: const Text("登录 / 注册"),
                      ),
                    ),
                ],
              ),

              // --- 2. Hero 主视觉区域 ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "跨平台 · 开源 · 高效",
                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "为协作同步而生的\n全能工作台",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "集成博客管理、GPT 团队邀请、云盘存储与临时邮箱。\n支持 Windows, Android, iOS 及 Web 全平台。",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(height: 48),
                      // 大按钮
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 8,
                          shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("立即开始"),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- 3. 功能特性展示区 (填充内容) ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFeatureCard(context, Icons.article, "个人博客", "支持 Markdown 编辑与权限管理"),
                      _buildFeatureCard(context, Icons.cloud, "云盘存储", "私有化部署的文件管理系统"),
                      _buildFeatureCard(context, Icons.email, "临时邮箱", "保护隐私，远离垃圾邮件"),
                      _buildFeatureCard(context, Icons.smart_toy, "GPT 助手", "自动化团队邀请与管理"),
                    ],
                  ),
                ),
              ),

              // --- 4. 底部 Footer ---
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "© 2026 Team Space Open Source Project. Designed by FILWY2824.",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 构建功能卡片
  Widget _buildFeatureCard(BuildContext context, IconData icon, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey[200]!),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }
}