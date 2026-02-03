// lib/pages/user_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import 'landing_page.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  Future<void> _openEditSheet(BuildContext context) async {
    final app = AppService();
    final user = app.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.name);
    final bioCtrl = TextEditingController(text: app.bio);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.86),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text("编辑资料", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "昵称",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "简介",
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          app.updateProfile(name: nameCtrl.text, bio: bioCtrl.text);
                          Navigator.pop(context);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text("保存"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _logout(BuildContext context) {
    AppService().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        final app = AppService();
        final user = app.currentUser;
        final theme = Theme.of(context);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text("账户与设置"),
                actions: [
                  IconButton(
                    tooltip: "编辑资料",
                    onPressed: user == null ? null : () => _openEditSheet(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    children: [
                      // 顶部用户卡（玻璃质感）
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.65),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  child: Text(
                                    (user?.name.isNotEmpty == true)
                                        ? user!.name.characters.first.toUpperCase()
                                        : "U",
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.name ?? "未登录",
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user?.email ?? "请先登录以管理设置",
                                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _pill(context, icon: Icons.verified_user_outlined, text: user?.role ?? "-"),
                                          _pill(context, icon: Icons.badge_outlined, text: app.bio.isEmpty ? "未填写简介" : app.bio),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.tonalIcon(
                                  onPressed: user == null ? null : () => _openEditSheet(context),
                                  icon: const Icon(Icons.tune),
                                  label: const Text("编辑"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 外观与偏好
                      Card.filled(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.palette_outlined),
                                title: const Text("外观"),
                                subtitle: const Text("Material 3 · 动态主题"),
                                trailing: SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment(value: ThemeMode.light, label: Text("亮色"), icon: Icon(Icons.light_mode_outlined)),
                                    ButtonSegment(value: ThemeMode.system, label: Text("跟随"), icon: Icon(Icons.auto_awesome_outlined)),
                                    ButtonSegment(value: ThemeMode.dark, label: Text("暗色"), icon: Icon(Icons.dark_mode_outlined)),
                                  ],
                                  selected: {app.themeMode},
                                  onSelectionChanged: (s) => app.setThemeMode(s.first),
                                ),
                              ),
                              const Divider(height: 16),
                              SwitchListTile.adaptive(
                                value: app.denseMode,
                                onChanged: (v) => app.setDenseMode(v),
                                secondary: const Icon(Icons.view_compact_outlined),
                                title: const Text("紧凑模式"),
                                subtitle: const Text("更紧凑的列表与布局（可按需接入各页面）"),
                              ),
                              SwitchListTile.adaptive(
                                value: app.reduceMotion,
                                onChanged: (v) => app.setReduceMotion(v),
                                secondary: const Icon(Icons.motion_photos_off_outlined),
                                title: const Text("减少动效"),
                                subtitle: const Text("降低动画和模糊效果（Web 更省资源）"),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 退出登录
                      Card.filled(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const ListTile(
                                leading: Icon(Icons.security_outlined),
                                title: Text("安全"),
                                subtitle: Text("退出登录会清除本地登录态"),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: user == null ? null : () => _logout(context),
                                  icon: const Icon(Icons.logout),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text("退出登录"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(BuildContext context, {required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
