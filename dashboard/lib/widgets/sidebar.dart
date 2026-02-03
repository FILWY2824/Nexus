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
        final borderColor = isDark ? Colors.transparent : const Color(0xFFEEEEEE);

        // 2. 动画容器
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCollapsed ? 72 : 260, // 稍微调整宽度，让折叠态更舒服
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 宽度小于 150 视为折叠态
              final isRenderCollapsed = constraints.maxWidth < 150;

              return Column(
                children: [
                  const SizedBox(height: 24),

                  // ===========================
                  // 1. Logo 区域 (Nexus)
                  // ===========================
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
                        height: 50, 
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: isRenderCollapsed 
                              ? MainAxisAlignment.center 
                              : MainAxisAlignment.start,
                          children: [
                            // Logo 图标：加个背景色更显眼
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.hub, 
                                color: Colors.white, 
                                size: 20
                              ),
                            ),
                            
                            if (!isRenderCollapsed) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Nexus", // 改名
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
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
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

                  const SizedBox(height: 32),

                  // ===========================
                  // 2. 菜单列表
                  // ===========================
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

                  // ===========================
                  // 3. 现代化折叠按钮
                  // ===========================
                  // 不再是简单的 IconButton，而是一个美观的触发区
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onToggleCollapse,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            // 加上淡淡的背景，像一个功能块
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)
                            )
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 图标：根据状态切换
                              Icon(
                                isCollapsed ? Icons.keyboard_double_arrow_right : Icons.menu_open,
                                size: 18,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                              // 展开时显示文字
                              if (!isRenderCollapsed) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "收起侧边栏",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1),

                  // ===========================
                  // 4. 用户头像
                  // ===========================
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (!appService.isLoggedIn) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                                child: Text(
                                  appService.isLoggedIn ? appService.currentUser!.name : "点击登录",
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
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

  // 构建菜单项
  Widget _buildMenuItem(BuildContext context, int index, String title, IconData icon, bool renderCollapsed) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final iconColor = isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]);
    final selectedBgColor = primaryColor.withOpacity(isDark ? 0.2 : 0.08);

    if (renderCollapsed) {
      // --- 折叠态 (图标) ---
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Tooltip(
              message: title,
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
        ),
      );
    } else {
      // --- 展开态 (列表项) ---
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(icon, color: iconColor, size: 20),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          selected: isSelected,
          selectedTileColor: selectedBgColor,
          onTap: () => onItemSelected(index),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          dense: true, // 让列表项紧凑一点，更像桌面端软件
        ),
      );
    }
  }
}