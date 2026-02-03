// lib/pages/blog_page.dart
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import 'editor_page.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final MockService _apiService = MockService();
  String _searchQuery = "";

  Key _listKey = UniqueKey();
  void _refreshList() => setState(() => _listKey = UniqueKey());

  Future<void> _showPromoteDialog() async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("提升用户为管理员"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "目标用户邮箱（targetEmail）",
              hintText: "example@domain.com",
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("提升")),
          ],
        );
      },
    );

    if (ok != true) return;

    final targetEmail = controller.text.trim();
    if (targetEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("邮箱不能为空")));
      }
      return;
    }

    final success = await AppService().promoteToAdmin(targetEmail);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已提升为管理员")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppService().lastError ?? "提升失败")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        final appService = AppService();
        final canWrite = appService.isAdmin;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            final horizontalPadding = isDesktop ? 40.0 : 16.0;

            return Scaffold(
              backgroundColor: Colors.transparent,

              floatingActionButton: canWrite
                  ? FloatingActionButton.extended(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditorPage()));
                        _refreshList();
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("写文章"),
                    )
                  : null,

              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      children: [
                        const Text("文章列表", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const Spacer(),

                        // ✅ 管理员按钮：提升用户权限
                        if (canWrite)
                          IconButton(
                            tooltip: "提升用户为管理员",
                            onPressed: _showPromoteDialog,
                            icon: const Icon(Icons.admin_panel_settings_outlined),
                          ),

                        if (isDesktop) SizedBox(width: 300, child: _buildSearchBar(isDark)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: FutureBuilder<List<Article>>(
                      key: _listKey,
                      future: _apiService.getArticles(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text("加载失败: ${snapshot.error}"));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text("暂无文章"));
                        }

                        final filtered = snapshot.data!.where((a) {
                          if (_searchQuery.isEmpty) return true;
                          final q = _searchQuery.toLowerCase();
                          return a.title.toLowerCase().contains(q) ||
                              a.summary.toLowerCase().contains(q) ||
                              a.author.toLowerCase().contains(q);
                        }).toList();

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final article = filtered[index];
                            return _buildArticleCard(article, canWrite);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      decoration: InputDecoration(
        hintText: "搜索文章...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
    );
  }

  Widget _buildArticleCard(Article article, bool canWrite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(article.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: canWrite
            ? IconButton(
                tooltip: "编辑",
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditorPage(article: article)),
                  );
                  _refreshList();
                },
              )
            : null,
      ),
    );
  }
}
