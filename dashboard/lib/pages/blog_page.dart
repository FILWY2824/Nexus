// lib/pages/blog_page.dart
import 'package:flutter/material.dart';
import '../models/data_model.dart';
import '../services/mock_service.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  // 搜索关键词
  String _searchQuery = "";
  // 排序方式：0-时间, 1-热度(浏览量), 2-相关性
  int _sortType = 0;

  @override
  Widget build(BuildContext context) {
    // 获取全局服务实例
    final service = AppService();
    
    // 监听数据变化（如添加了新博客）
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        // 1. 过滤数据
        List<BlogPost> displayPosts = service.posts.where((post) {
          return post.title.contains(_searchQuery) || post.summary.contains(_searchQuery);
        }).toList();

        // 2. 排序数据
        displayPosts.sort((a, b) {
          switch (_sortType) {
            case 1: // 按浏览量 (降序)
              return b.views.compareTo(a.views);
            case 2: // 按相关性 (简单模拟：标题匹配度高排前面)
              bool aHas = a.title.contains(_searchQuery);
              bool bHas = b.title.contains(_searchQuery);
              if (aHas && !bHas) return -1;
              if (!aHas && bHas) return 1;
              return 0;
            case 0: // 按时间 (最新在前)
            default:
              return b.publishDate.compareTo(a.publishDate);
          }
        });

        return Scaffold(
          // 如果是管理员，显示右下角悬浮按钮
          floatingActionButton: service.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () {
                    // TODO: 跳转到编辑页面
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("管理员权限：打开编辑器"))
                    );
                  },
                  label: const Text("写博客"),
                  icon: const Icon(Icons.edit),
                )
              : null, // 游客不显示按钮
          
          body: Column(
            children: [
              // --- 顶部工具栏：搜索 + 排序 ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    const Text("文章列表", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    
                    // 搜索框
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: "搜索标题或内容...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // 排序下拉菜单
                    DropdownButton<int>(
                      value: _sortType,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("按时间排序")),
                        DropdownMenuItem(value: 1, child: Text("按热度排序")),
                        DropdownMenuItem(value: 2, child: Text("按相关性")),
                      ],
                      onChanged: (val) => setState(() => _sortType = val ?? 0),
                    )
                  ],
                ),
              ),
              const Divider(),

              // --- 博客列表区域 ---
              Expanded(
                child: displayPosts.isEmpty 
                  ? const Center(child: Text("没有找到相关文章"))
                  : ListView.builder(
                      itemCount: displayPosts.length,
                      itemBuilder: (context, index) {
                        final post = displayPosts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(post.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(post.author, style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(width: 16),
                                    Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text("${post.views}", style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(width: 16),
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text("${post.publishDate.toString().split(' ')[0]}", style: TextStyle(color: Colors.grey[600])),
                                  ],
                                )
                              ],
                            ),
                            trailing: service.isAdmin 
                                ? IconButton(icon: const Icon(Icons.edit), onPressed: (){}) 
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: 跳转到博客详情页
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}