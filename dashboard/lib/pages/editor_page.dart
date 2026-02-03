// lib/pages/editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/mock_service.dart';

class EditorPage extends StatefulWidget {
  final Article? article;
  const EditorPage({super.key, this.article});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final MockService _apiService = MockService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article?.title ?? "");
    _contentController = TextEditingController(text: widget.article?.content ?? "");
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("标题不能为空")));
      return;
    }

    if (!AppService().isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("只有管理员才能发布/编辑文章")));
      return;
    }

    setState(() => _isLoading = true);

    final success = await _apiService.publishArticle(
      _titleController.text.trim(),
      _contentController.text,
      widget.article?.id,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("发布成功！")));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("发布失败：请确认你是管理员且账号密码正确")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = ValueNotifier<bool>(false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article == null ? "新建文章" : "编辑文章"),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isPreview,
            builder: (context, preview, _) {
              return IconButton(
                tooltip: preview ? "编辑" : "预览",
                icon: Icon(preview ? Icons.edit_outlined : Icons.preview_outlined),
                onPressed: () => isPreview.value = !preview,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send, size: 16),
              label: Text(_isLoading ? "发布中..." : "发布"),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: isPreview,
        builder: (context, preview, _) {
          if (preview) {
            return Markdown(
              data: "# ${_titleController.text}\n\n${_contentController.text}",
              padding: const EdgeInsets.all(16),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "标题",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: "正文（Markdown）",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: null,
                    expands: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
