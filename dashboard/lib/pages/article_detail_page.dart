import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../services/mock_service.dart';
import '../widgets/yuque_markdown_view.dart';

class ArticleDetailPage extends StatefulWidget {
  final Article article;

  const ArticleDetailPage({super.key, required this.article});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final TocController _tocController = TocController();
  late final Future<Article> _articleFuture;

  @override
  void initState() {
    super.initState();
    _articleFuture = _loadArticle();
  }

  Future<Article> _loadArticle() async {
    // List API (for perf) may omit `content`. When empty, fetch the full doc.
    if (widget.article.content.isNotEmpty) return widget.article;
    final full = await MockService().getArticleById(widget.article.id);
    return full ?? widget.article;
  }

  @override
  void dispose() {
    _tocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Article>(
      future: _articleFuture,
      builder: (context, snapshot) {
        final article = snapshot.data ?? widget.article;
        final dateStr = article.publishDate.toString().split(' ')[0];

        return Scaffold(
          appBar: AppBar(title: Text(article.title)),
          body: Column(
            children: [
              // 头部元数据区域
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.title, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        IconText(icon: Icons.person, text: article.author),
                        IconText(icon: Icons.calendar_today, text: dateStr),
                        IconText(icon: Icons.visibility, text: "${article.views} 阅读"),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const IconText(icon: Icons.downloading, text: "加载中..."),
                      ],
                    ),
                  ],
                ),
              ),
              // Yuque-like Markdown 渲染（支持 TOC / LaTeX / 图片点击放大）
              Expanded(child: _buildMarkdownArea(context, article.content)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarkdownArea(BuildContext context, String content) {
    if (content.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (!isWide) {
          return YuqueMarkdownView(
            data: content,
            selectable: true,
            padding: const EdgeInsets.all(16),
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 260,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: TocWidget(controller: _tocController),
              ),
            ),
            Expanded(
              child: YuqueMarkdownView(
                data: content,
                tocController: _tocController,
                selectable: true,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 辅助组件：带图标的文字
class IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const IconText({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}