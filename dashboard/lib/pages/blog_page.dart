// lib/pages/blog_page.dart
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import 'editor_page.dart';
import 'article_detail_page.dart';

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
      clipBehavior: Clip.antiAlias, // 确保点击水波纹不溢出
      child: InkWell(
        // 1. 点击跳转到详情页
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ArticleDetailPage(article: article)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题与操作栏
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      article.title, 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (canWrite) ...[
                    // 编辑按钮
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: "编辑",
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditorPage(article: article)),
                        );
                        _refreshList();
                      },
                    ),
                    const SizedBox(width: 8),
                    // 2. 删除按钮
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: "删除",
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDelete(article),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 8),
              
              // 摘要
              Text(
                article.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
              ),
              const SizedBox(height: 12),

              // 底部信息栏 (PublishDate, Views, Author)
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(article.author, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 16),
                  
                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    article.publishDate.toString().split(' ')[0], // ✅ 修正：先转字符串再分割
                    style: const TextStyle(fontSize: 12, color: Colors.grey)
                  ),
                  const Spacer(),
                  
                  Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("${article.views}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 删除确认弹窗
  Future<void> _confirmDelete(Article article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("确认删除"),
        content: Text("确定要删除文章《${article.title}》吗？此操作无法撤销。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("删除"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _apiService.deleteArticle(article.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除")));
          _refreshList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("删除失败")));
        }
      }
    }
  }
}
