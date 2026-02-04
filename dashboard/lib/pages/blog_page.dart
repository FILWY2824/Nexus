// lib/pages/blog_page.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mock_service.dart';
import 'article_detail_page.dart';
import 'editor_page.dart';

/// ✅ BlogPage is now a **nested Navigator**.
/// This keeps the global left Sidebar always visible (Yuque-like workspace).
///
/// LandingPage/Sidebar renders BlogPage on the right; inside BlogPage we navigate
/// between:
/// - list
/// - detail
/// - editor
///
/// So when you open an article, it only replaces the **right panel**, not the whole app.
class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const _BlogListScreen());
      },
    );
  }
}

// ===========================
// Modern list screen
// ===========================

enum _SortMode { timeDesc, timeAsc, relevance }

class _BlogListScreen extends StatefulWidget {
  const _BlogListScreen();

  @override
  State<_BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends State<_BlogListScreen> {
  final MockService _api = MockService();

  // data
  List<Article> _articles = [];
  bool _loading = false;
  String? _error;

  // UI state
  String _query = '';
  _SortMode _sort = _SortMode.timeDesc;
  String _statusFilter = 'published'; // published / draft / all (admin)

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);

    // ✅ Real-time-ish: polling refresh (cheap + stable)
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _load(showLoading: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool showLoading}) async {
    if (_loading) return;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await _api.getArticles(status: _statusFilter);

      // Diff update: avoid rebuilding if nothing changed
      if (!_sameList(_articles, list)) {
        setState(() {
          _articles = list;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = '加载失败：$e');
    } finally {
      if (showLoading) setState(() => _loading = false);
    }
  }

  bool _sameList(List<Article> a, List<Article> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].publishDate != b[i].publishDate) return false;
      if (a[i].views != b[i].views) return false;
      if (a[i].title != b[i].title) return false;
    }
    return true;
  }

  List<Article> _filteredAndSorted() {
    final q = _query.trim().toLowerCase();

    var list = _articles.where((a) {
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          a.summary.toLowerCase().contains(q) ||
          a.author.toLowerCase().contains(q);
    }).toList();

    int score(Article a) {
      if (q.isEmpty) return 0;
      int s = 0;
      if (a.title.toLowerCase().contains(q)) s += 3;
      if (a.summary.toLowerCase().contains(q)) s += 2;
      if (a.author.toLowerCase().contains(q)) s += 1;
      return s;
    }

    switch (_sort) {
      case _SortMode.timeAsc:
        list.sort((a, b) => a.publishDate.compareTo(b.publishDate));
        break;
      case _SortMode.relevance:
        if (q.isEmpty) {
          list.sort((a, b) => b.publishDate.compareTo(a.publishDate));
        } else {
          list.sort((a, b) {
            final sa = score(a);
            final sb = score(b);
            if (sa != sb) return sb.compareTo(sa);
            return b.publishDate.compareTo(a.publishDate);
          });
        }
        break;
      case _SortMode.timeDesc:
      default:
        list.sort((a, b) => b.publishDate.compareTo(a.publishDate));
        break;
    }

    return list;
  }

  Future<void> _openWriter({Article? article}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorPage(article: article)),
    );
    await _load(showLoading: true);
  }

  Future<void> _openArticle(Article article) async {
    if (article.status == 'draft') {
      // Drafts: open editor directly
      await _openWriter(article: article);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailPage(article: article)),
    );

    // Return from reading — refresh list (views might change)
    await _load(showLoading: false);
  }

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

    if (confirm != true) return;

    final ok = await _api.deleteArticle(article.id);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除")));
      await _load(showLoading: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppService().lastError ?? "删除失败")),
      );
    }
  }

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

    return AnimatedBuilder(
      animation: AppService(),
      builder: (context, _) {
        final app = AppService();
        final canWrite = app.isAdmin;

        // Non-admin: always show published
        if (!canWrite && _statusFilter != 'published') {
          _statusFilter = 'published';
          // fire a refresh (best-effort)
          WidgetsBinding.instance.addPostFrameCallback((_) => _load(showLoading: true));
        }

        final list = _filteredAndSorted();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => _openWriter(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text("写文章"),
                )
              : null,
          body: SafeArea(
            child: Column(
              children: [
                _Header(
                  isDark: isDark,
                  canWrite: canWrite,
                  query: _query,
                  sort: _sort,
                  status: _statusFilter,
                  onQueryChanged: (v) => setState(() => _query = v),
                  onSortChanged: (v) => setState(() => _sort = v),
                  onStatusChanged: (v) async {
                    setState(() => _statusFilter = v);
                    await _load(showLoading: true);
                  },
                  onRefresh: () => _load(showLoading: true),
                  onPromote: canWrite ? _showPromoteDialog : null,
                  loading: _loading,
                  resultCount: list.length,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(showLoading: true),
                    child: _error != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                            ],
                          )
                        : _loading && _articles.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : list.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 80),
                                      Center(child: Text("暂无文章")),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final a = list[index];
                                      return _ArticleCard(
                                        article: a,
                                        canWrite: canWrite,
                                        query: _query,
                                        onOpen: () => _openArticle(a),
                                        onEdit: () => _openWriter(article: a),
                                        onDelete: () => _confirmDelete(a),
                                      );
                                    },
                                  ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isDark,
    required this.canWrite,
    required this.query,
    required this.sort,
    required this.status,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.loading,
    required this.resultCount,
    this.onPromote,
  });

  final bool isDark;
  final bool canWrite;

  final String query;
  final _SortMode sort;
  final String status;

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_SortMode> onSortChanged;
  final ValueChanged<String> onStatusChanged;

  final VoidCallback onRefresh;
  final VoidCallback? onPromote;

  final bool loading;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF111827) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("文章", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$resultCount",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (onPromote != null)
                IconButton(
                  tooltip: "提升用户为管理员",
                  onPressed: onPromote,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                ),
              IconButton(
                tooltip: "刷新",
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: card,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth >= 760;

                  final search = TextField(
                    decoration: InputDecoration(
                      hintText: "搜索标题 / 摘要 / 作者…",
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: onQueryChanged,
                  );

                  final sortDrop = DropdownButton<_SortMode>(
                    value: sort,
                    onChanged: (v) {
                      if (v != null) onSortChanged(v);
                    },
                    items: const [
                      DropdownMenuItem(value: _SortMode.timeDesc, child: Text("时间：最新")),
                      DropdownMenuItem(value: _SortMode.timeAsc, child: Text("时间：最早")),
                      DropdownMenuItem(value: _SortMode.relevance, child: Text("相关性")),
                    ],
                  );

                  final statusToggle = canWrite
                      ? ToggleButtons(
                          isSelected: [status == 'published', status == 'draft', status == 'all'],
                          onPressed: (i) {
                            final v = switch (i) { 0 => 'published', 1 => 'draft', _ => 'all' };
                            onStatusChanged(v);
                          },
                          borderRadius: BorderRadius.circular(10),
                          constraints: const BoxConstraints(minHeight: 34, minWidth: 66),
                          children: const [
                            Text("已发布", style: TextStyle(fontSize: 12)),
                            Text("草稿", style: TextStyle(fontSize: 12)),
                            Text("全部", style: TextStyle(fontSize: 12)),
                          ],
                        )
                      : const SizedBox.shrink();

                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        search,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            sortDrop,
                            const Spacer(),
                            if (canWrite) statusToggle,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      sortDrop,
                      const SizedBox(width: 12),
                      if (canWrite) statusToggle,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.canWrite,
    required this.query,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Article article;
  final bool canWrite;
  final String query;

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  TextSpan _highlight(String text, String q, TextStyle style, TextStyle hi) {
    if (q.trim().isEmpty) return TextSpan(text: text, style: style);
    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    final idx = lower.indexOf(needle);
    if (idx < 0) return TextSpan(text: text, style: style);

    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(text: text.substring(idx, idx + needle.length), style: hi),
        TextSpan(text: text.substring(idx + needle.length), style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metaColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final hi = TextStyle(
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

    final summaryStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: metaColor) ??
        TextStyle(fontSize: 14, color: metaColor);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: _highlight(article.title, query, titleStyle, hi),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.status == 'draft')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.orange.withOpacity(0.25)),
                      ),
                      child: const Text(
                        "草稿",
                        style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (canWrite) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: article.status == 'draft' ? "继续编辑" : "编辑",
                      constraints: const BoxConstraints(),
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: "删除",
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: _highlight(article.summary, query, summaryStyle, hi),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: metaColor),
                  const SizedBox(width: 4),
                  Text(article.author, style: TextStyle(fontSize: 12, color: metaColor)),
                  const SizedBox(width: 14),
                  Icon(Icons.access_time, size: 14, color: metaColor),
                  const SizedBox(width: 4),
                  Text(article.publishDate.toString().split(' ')[0], style: TextStyle(fontSize: 12, color: metaColor)),
                  const Spacer(),
                  Icon(Icons.visibility_outlined, size: 14, color: metaColor),
                  const SizedBox(width: 4),
                  Text("${article.views}", style: TextStyle(fontSize: 12, color: metaColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
