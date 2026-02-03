// lib/pages/dashboard.dart (排查专用版)
import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
// 暂时不引入 blog_page，防止它报错
// import 'blog_page.dart';
import 'email_page.dart';
import 'gpt_page.dart';
import 'landing_page.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text("Team Space"),
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                },
              ),
            ),
      
      drawer: isDesktop
          ? null
          : Sidebar(
              selectedIndex: _selectedIndex,
              isCollapsed: false, 
              onItemSelected: (index) {
                Navigator.pop(context);
                setState(() => _selectedIndex = index);
              },
              onToggleCollapse: () {},
            ),

      body: Row(
        children: [
          if (isDesktop)
            Sidebar(
              selectedIndex: _selectedIndex,
              isCollapsed: _isSidebarCollapsed, 
              onItemSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              onToggleCollapse: () {
                setState(() {
                  _isSidebarCollapsed = !_isSidebarCollapsed;
                });
              },
            ),

          Expanded(
            child: Container(
              // 给背景一个显眼的颜色
              color: Theme.of(context).scaffoldBackgroundColor,
              
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // --- 替换 BlogPage 为临时测试组件 ---
                  _buildTestPage("博客页面 (如果看到这个说明布局修好了)", Colors.blue),
                  
                  // 其他页面保持不变
                  const PlaceholderPage(title: "云盘存储"),
                  const EmailPage(),
                  const GptInvitePage(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 临时测试组件
  Widget _buildTestPage(String title, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: color),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text("$title 功能开发中..."));
  }
}