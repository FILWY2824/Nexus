// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import '../pages/login_page.dart';
import '../pages/landing_page.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed; // 这是目标状态（由父组件控制）
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
        
        // 兼容旧版 Flutter 的颜色写法
        final backgroundColor = isDark 
            ? const Color(0xFF1E293B) 
            : Colors.white;

        // 1. 外层：负责宽度的平滑动画
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCollapsed ? 70 : 260,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: (isDark || isCollapsed) 
                ? null 
                : const Border(right: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          
          // 2. 内层：LayoutBuilder 负责监听动画过程中的【实时宽度】
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 【核心修复】
              // 不直接用 isCollapsed，而是根据当前实际宽度判断。
              // 当宽度小于 150 时，强制认为处于“视觉折叠”状态。
              // 这样在展开动画的初期，内容依然保持折叠样式，直到宽度足够大才弹开文字。
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12, 
                          // 根据视觉状态调整边距
                          horizontal: isRenderCollapsed ? 8 : 24
                        ),
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
                            // 只有宽度足够时才显示文字
                            if (!isRenderCollapsed) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Team Space", 
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900, 
                                        fontSize: 18, 
                                        color: isDark ? Colors.white : Colors.black87
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
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
                        // 图标依然跟随目标状态(isCollapsed)，否则动画时图标会乱跳
                        isCollapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
                        color: Colors.grey,
                      ),
                      onPressed: onToggleCollapse,
                      tooltip: isCollapsed ? "展开侧边栏" : "折叠侧边栏",
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

  // 辅助方法：构建菜单项
  Widget _buildMenuItem(BuildContext context, int index, String title, IconData icon, bool renderCollapsed) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // 根据视觉状态调整外边距
      margin: EdgeInsets.symmetric(horizontal: renderCollapsed ? 8 : 12, vertical: 4),
      child: Tooltip(
        message: renderCollapsed ? title : "", 
        child: ListTile(
          // 【防崩关键】折叠时去掉内边距，给内容留出空间
          contentPadding: renderCollapsed 
              ? EdgeInsets.zero 
              : const EdgeInsets.symmetric(horizontal: 16),
          
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          
          // 【防崩关键】折叠时最小前导宽度设为0
          minLeadingWidth: renderCollapsed ? 0 : null,
          
          leading: Container(
             // 【防崩关键】折叠时限制宽度为 40，确保一定要小于 Sidebar 的总宽度
             width: renderCollapsed ? 40 : null,
             alignment: Alignment.center,
             child: Icon(
              icon,
              color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : (isDark ? Colors.grey[400] : Colors.grey),
            ),
          ),
          
          // 只有视觉上展开时才渲染标题 Text 组件
          title: renderCollapsed
              ? null
              : Text(
                  title,
                  style: TextStyle(
                    color: isSelected 
                        ? Theme.of(context).primaryColor 
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                
          selected: isSelected,
          selectedTileColor: Theme.of(context).primaryColor.withOpacity(isDark ? 0.2 : 0.1),
          onTap: () => onItemSelected(index),
        ),
      ),
    );
  }
}