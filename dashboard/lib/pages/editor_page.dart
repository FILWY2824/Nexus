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
  final MockService _apiService = MockService(); // 使用真 API
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article?.title ?? "");
    _contentController = TextEditingController(text: widget.article?.content ?? "");
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("标题不能为空")));
      return;
    }
    
    setState(() => _isLoading = true);
    
    final success = await _apiService.publishArticle(
      _titleController.text, 
      _contentController.text,
      widget.article?.id
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("发布成功！")));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("发布失败，请检查网络或权限")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article == null ? "新建文章" : "编辑文章"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send, size: 16),
              label: Text(_isLoading ? "提交中..." : "发布"),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: "文章标题", border: InputBorder.none),
                  ),
                  const Divider(),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(hintText: "在此输入内容 (支持 Markdown)...", border: InputBorder.none),
                      onChanged: (val) => setState((){}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Markdown(data: _contentController.text),
            ),
          ),
        ],
      ),
    );
  }
}