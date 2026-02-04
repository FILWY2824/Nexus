// lib/pages/dashboard.dart
import 'package:flutter/material.dart';

import 'package:dashboard/features/workspace/widgets/sidebar.dart';
import 'package:dashboard/features/blog/pages/blog_page.dart';
import 'package:dashboard/features/tools/email/email_page.dart';
import 'package:dashboard/features/tools/gpt/gpt_page.dart';
import 'package:dashboard/features/home/landing_page.dart';


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
      // 手机端 AppBar
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text("Nexus"),
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
      
      // 手机端抽屉
      drawer: isDesktop
          ? null
          : Sidebar(
              selectedIndex: _selectedIndex,
              isCollapsed: false, 
              onItemSelected: (index) {
                Navigator.pop(context); // 关闭抽屉
                setState(() => _selectedIndex = index);
              },
              onToggleCollapse: () {},
            ),

      body: Row(
        children: [
          // 电脑端侧边栏
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

          // 右侧内容区
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: IndexedStack(
                index: _selectedIndex,
                // 【修正】这里去掉了 const
                children: const [
                  BlogPage(),
                  PlaceholderPage(title: "云盘存储功能开发中..."),
                  EmailPage(), // 这里不再报错
                  GptInvitePage(),
                ],
              ),
            ),
          ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_queue, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 18)),
        ],
      ),
    );
  }
}