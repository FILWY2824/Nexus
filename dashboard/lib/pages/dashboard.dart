// lib/pages/dashboard.dart
import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
import 'blog_page.dart';
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
      // 手机端 AppBar
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text("Nexus"), // 改名
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
              color: Theme.of(context).scaffoldBackgroundColor,
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  BlogPage(),
                  PlaceholderPage(title: "云盘存储功能开发中..."),
                  EmailPage(),
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