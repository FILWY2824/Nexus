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
        
        // 1. 颜色兼容
        final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;

        // 2. 动画容器
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCollapsed ? 70 : 260,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: (isDark || isCollapsed) 
                ? null 
                : const Border(right: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          
          // 3. 布局构建器：实时监听宽度，决定显示模式
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 只要宽度小于 150，就强制使用精简模式 (Icon Only)
              // 这样能绝对避免 ListTile 在窄宽度下的报错
              final isRenderCollapsed = constraints.maxWidth < 150;

              return Column(
                children: [
                  const SizedBox(height: 24),

                  // --- Logo 区域 ---
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LandingPage()),
                          (route) => false,
                        );
                      },
                      child: Container(
                        // 保证点击区域高度一致
                        height: 50, 
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: isRenderCollapsed 
                              ? MainAxisAlignment.center 
                              : MainAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.hub_outlined, 
                              color: Theme.of(context).primaryColor, 
                              size: 28
                            ),
                            if (!isRenderCollapsed) ...[
                              const SizedBox(width: 12),
                              // 使用 Flexible 防止文字溢出报错
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Team Space", 
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900, 
                                        fontSize: 18, 
                                        color: isDark ? Colors.white : Colors.black87
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      "Workspace", 
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- 菜单列表 ---
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

                  // --- 折叠按钮 ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: IconButton(
                      icon: Icon(
                        isCollapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
                        color: Colors.grey,
                      ),
                      onPressed: onToggleCollapse,
                    ),
                  ),
                  const Divider(height: 1),

                  // --- 用户头像 ---
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (!appService.isLoggedIn) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: isRenderCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: appService.isLoggedIn ? Theme.of(context).primaryColor : Colors.grey,
                              radius: 16,
                              child: Icon(appService.isLoggedIn ? Icons.person : Icons.login, color: Colors.white, size: 16),
                            ),
                            if (!isRenderCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  appService.isLoggedIn ? appService.currentUser!.name : "点击登录",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }
          ),
        );
      },
    );
  }

  // 构建菜单项 (防崩核心)
  Widget _buildMenuItem(BuildContext context, int index, String title, IconData icon, bool renderCollapsed) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final iconColor = isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey);

    // 选中时的背景色
    final selectedBgColor = primaryColor.withOpacity(isDark ? 0.2 : 0.1);

    if (renderCollapsed) {
      // === 模式 A：折叠状态 (Icon Only) ===
      // 直接使用 Container + Icon，不使用 ListTile，绝对不会报错
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(index),
          child: Container(
            height: 50, // 固定高度
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Tooltip(
              message: title, // 鼠标悬停显示文字
              child: Icon(icon, color: iconColor),
            ),
          ),
        ),
      );
    } else {
      // === 模式 B：展开状态 (完整列表项) ===
      // 宽度足够，使用标准的 ListTile
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(icon, color: iconColor),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedTileColor: selectedBgColor,
          onTap: () => onItemSelected(index),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
    }
  }
}