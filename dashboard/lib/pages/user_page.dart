import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import 'landing_page.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  Future<void> _editAndSave(BuildContext context) async {
    final app = AppService();
    final user = app.currentUser;
    if (user == null) return;

    final theme = Theme.of(context);
    final nameCtrl = TextEditingController(text: user.name);
    final bioCtrl = TextEditingController(text: app.bio);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: theme.colorScheme.surface.withOpacity(0.92),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Text(
                          "编辑资料",
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 昵称
                    TextField(
                      controller: nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "昵称",
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ 个人简介：优化重点（顶部对齐、不居中、更现代）
                    TextField(
                      controller: bioCtrl,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 4,
                      maxLines: 8,
                      textAlign: TextAlign.start,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: "个人简介",
                        hintText: "写一段介绍，让别人更快认识你…",
                        alignLabelWithHint: true,
                        // 让图标偏上，不要居中
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Icon(Icons.badge_outlined),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(12, 26, 12, 16),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text("保存并同步到数据库"),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (ok == true) {
      final success = await app.updateProfileRemote(
        name: nameCtrl.text,
        bio: bioCtrl.text,
      );

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已同步到 MySQL")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.lastError ?? "更新失败")),
        );
      }
    }
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
                    onPressed: user == null ? null : () => _editAndSave(context),
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
                      // 顶部用户卡：✅ 隐藏 role / updated_at，改为展示个人简介
                      Card.filled(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                child: Text(user?.name.isNotEmpty == true ? user!.name.characters.first : "U"),
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
                                      user?.email ?? "请先登录",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // ✅ 个人简介展示（主显示）
                                    Text(
                                      "个人简介",
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: theme.colorScheme.outlineVariant.withOpacity(0.45),
                                        ),
                                      ),
                                      child: Text(
                                        (app.bio.isNotEmpty)
                                            ? app.bio
                                            : "还没有简介，点击右侧“编辑”添加一段介绍吧～",
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          height: 1.35,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.tonalIcon(
                                onPressed: user == null ? null : () => _editAndSave(context),
                                icon: const Icon(Icons.tune),
                                label: const Text("编辑"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 外观与偏好（保持你原来的）
                      Card.filled(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.palette_outlined),
                              title: const Text("外观"),
                              subtitle: const Text("Material 3"),
                              trailing: SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(value: ThemeMode.light, label: Text("亮色")),
                                  ButtonSegment(value: ThemeMode.system, label: Text("跟随")),
                                  ButtonSegment(value: ThemeMode.dark, label: Text("暗色")),
                                ],
                                selected: {app.themeMode},
                                onSelectionChanged: (s) => app.setThemeMode(s.first),
                              ),
                            ),
                            const Divider(height: 0),
                            SwitchListTile.adaptive(
                              value: app.denseMode,
                              onChanged: (v) => app.setDenseMode(v),
                              secondary: const Icon(Icons.view_compact_outlined),
                              title: const Text("紧凑模式"),
                            ),
                            SwitchListTile.adaptive(
                              value: app.reduceMotion,
                              onChanged: (v) => app.setReduceMotion(v),
                              secondary: const Icon(Icons.motion_photos_off_outlined),
                              title: const Text("减少动效"),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      Card.filled(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
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
}
