// lib/pages/blog_page.dart
import 'package:flutter/material.dart';
import '../services/mock_service.dart';
import 'editor_page.dart'; // 确保引入编辑器

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final MockService _apiService = MockService();
  String _searchQuery = "";
  
  // 用于触发刷新的 Key
  Key _listKey = UniqueKey();

  void _refreshList() {
    setState(() => _listKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    // 获取全局状态
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 使用 ListenableBuilder 监听登录状态变化 (确保登录后按钮自动出现)
    return ListenableBuilder(
      listenable: AppService(),
      builder: (context, _) {
        final appService = AppService();
        final canWrite = appService.isAdmin; // 只有 admin 才能写/改

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            final horizontalPadding = isDesktop ? 40.0 : 16.0;

            return Scaffold(
              backgroundColor: Colors.transparent,
              
              // 【悬浮按钮】只有管理员登录才显示
              floatingActionButton: canWrite ? FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const EditorPage())
                  );
                  _refreshList(); // 返回后刷新列表
                },
                icon: const Icon(Icons.edit),
                label: const Text("写文章"),
              ) : null,

              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  
                  // 头部区域
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      children: [
                        const Text("文章列表", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (isDesktop) 
                          SizedBox(width: 300, child: _buildSearchBar(isDark)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // 列表区域 (异步加载)
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
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                const Text("暂无文章，快去发布一篇吧！", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                        // 本地搜索过滤
                        final filtered = snapshot.data!.where((a) => 
                          a.title.toLowerCase().contains(_searchQuery.toLowerCase())
                        ).toList();

                        return ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildArticleCard(context, filtered[index], isDark, canWrite);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 44, 
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200], 
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "搜索文章...",
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, Article article, bool isDark, bool canEdit) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(article.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                // 【编辑按钮】管理员可见
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue),
                    tooltip: "编辑",
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditorPage(article: article))
                      );
                      _refreshList();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              article.summary.isNotEmpty ? article.summary : "暂无摘要",
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(article.author, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(article.publishDate.toString().substring(0, 10), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}