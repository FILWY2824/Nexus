// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import '../pages/login_page.dart';
import '../pages/landing_page.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        final appService = AppService();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFEEEEEE);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: isCollapsed ? 64 : 260,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(right: BorderSide(color: borderColor, width: 1)),
          ),
          
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isRenderCollapsed = constraints.maxWidth < 150;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildLogo(context, isRenderCollapsed, isDark),
                      const SizedBox(height: 32),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildMenuItem(context, 0, '个人博客', Icons.article_outlined, isRenderCollapsed),
                            _buildMenuItem(context, 1, '云盘存储', Icons.cloud_queue, isRenderCollapsed),
                            _buildMenuItem(context, 2, '邮箱注册', Icons.email_outlined, isRenderCollapsed),
                            _buildMenuItem(context, 3, 'GPT 邀请', Icons.smart_toy_outlined, isRenderCollapsed),
                          ],
                        ),
                      ),
                      _buildUserAvatar(context, appService, isRenderCollapsed, isDark),
                      const SizedBox(height: 20),
                    ],
                  ),

                  // 悬浮折叠按钮
                  Positioned(
                    top: 0, 
                    bottom: 0, 
                    right: -14, 
                    child: Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleCollapse,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 28,  
                            height: 80, 
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFA5F3FC).withOpacity(0.9), 
                                  const Color(0xFF38BDF8).withOpacity(0.8), 
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withOpacity(0.4), 
                                  blurRadius: 15, 
                                  spreadRadius: 0, 
                                  offset: const Offset(0, 0),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isCollapsed ? Icons.keyboard_double_arrow_right : Icons.chevron_left,
                              color: const Color(0xFF0C4A6E), 
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          ),
        );
      },
    );
  }

  Widget _buildLogo(BuildContext context, bool isCollapsed, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandingPage()), (route) => false);
        },
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.hub, color: Theme.of(context).primaryColor, size: 20),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nexus", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const Text("Workspace", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, int index, String title, IconData icon, bool renderCollapsed) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    if (renderCollapsed) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onItemSelected(index),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Tooltip(
                message: title,
                child: Icon(icon, color: isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]), size: 20),
              ),
            ),
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(icon, color: isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]), size: 20),
          title: Text(
            title,
            // 【核心修改】字体大小调整为 15，选中时加粗
            style: TextStyle(
              color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 15, 
            ),
          ),
          onTap: () => onItemSelected(index),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          dense: true,
          minLeadingWidth: 24,
        ),
      );
    }
  }

  Widget _buildUserAvatar(BuildContext context, AppService appService, bool isRenderCollapsed, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!appService.isLoggedIn) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isRenderCollapsed ? 4 : 8),
          padding: EdgeInsets.symmetric(horizontal: isRenderCollapsed ? 0 : 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFEEEEEE))),
          ),
          child: Row(
            mainAxisAlignment: isRenderCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: appService.isLoggedIn ? Theme.of(context).primaryColor : Colors.grey[300],
                radius: 14,
                child: Icon(appService.isLoggedIn ? Icons.person : Icons.login, color: Colors.white, size: 14),
              ),
              if (!isRenderCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appService.isLoggedIn ? appService.currentUser!.name : "点击登录",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (appService.isLoggedIn)
                        const Text("在线", style: TextStyle(color: Colors.green, fontSize: 10))
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}