// lib/pages/editor_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ✅ 渲染引擎
import 'package:markdown_widget/markdown_widget.dart';
// ✅ 拖拽支持
import 'package:desktop_drop/desktop_drop.dart';
// ✅ 文件选择支持
import 'package:image_picker/image_picker.dart';
// ✅ HTTP 请求
import 'package:http/http.dart' as http;
// ✅ 超级剪贴板
import 'package:super_clipboard/super_clipboard.dart';

import '../services/mock_service.dart';
import '../widgets/yuque_markdown_view.dart';

// 定义视图模式
enum EditorMode { edit, split, preview }

class EditorPage extends StatefulWidget {
  final Article? article;
  const EditorPage({super.key, this.article});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final ScrollController _editScrollController = ScrollController();
  
  // ✅ 预览防抖与通知
  late final ValueNotifier<String> _previewNotifier;
  Timer? _debounceTimer;

  // 状态
  EditorMode _mode = EditorMode.split;
  bool _isLoading = false;
  bool _isDragging = false;
  final TocController _tocController = TocController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article?.title ?? "");
    _contentController = TextEditingController(text: widget.article?.content ?? "");
    _previewNotifier = ValueNotifier(_contentController.text);

    // List API may omit `content` for performance; ensure we have the full doc when editing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFullArticleIfNeeded();
    });
  }

  Future<void> _ensureFullArticleIfNeeded() async {
    final art = widget.article;
    if (art == null) return;
    if (art.content.isNotEmpty) return;
    setState(() => _isLoading = true);
    final full = await MockService().getArticleById(art.id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载文章内容失败')),
      );
      return;
    }
    _titleController.text = full.title;
    _contentController.text = full.content;
    _previewNotifier.value = full.content;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _editScrollController.dispose();
    _previewNotifier.dispose();
    _debounceTimer?.cancel();
    _tocController.dispose();
    super.dispose();
  }

  // ================= 防抖更新 =================
  void _onContentChanged(String text) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _previewNotifier.value = text;
    });
  }

  // ================= 核心：超级粘贴逻辑 (仿语雀) =================

  Future<void> _handlePaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return; 

    final reader = await clipboard.read();

    if (reader.canProvide(Formats.png) || 
        reader.canProvide(Formats.jpeg) || 
        reader.canProvide(Formats.webp)) {
      
      debugPrint("📷 检测到剪贴板包含图片，准备读取...");
      setState(() => _isLoading = true);

      try {
        final readerFunc = reader.getFile(Formats.png, (file) async {
           final bytes = await file.readAll();
           final filename = file.fileName ?? "pasted_image.png";
           final url = await _uploadImageBytes(bytes, filename);
           
           if (mounted) {
             setState(() => _isLoading = false);
             if (url != null) {
               _insertImageMarkdown(url, "image");
               _onContentChanged(_contentController.text);
             }
           }
        });
        
        if (readerFunc == null) {
           reader.getFile(Formats.jpeg, (file) async {
             final bytes = await file.readAll();
             final url = await _uploadImageBytes(bytes, "pasted_image.jpg");
             if (mounted) {
               setState(() => _isLoading = false);
               if (url != null) {
                 _insertImageMarkdown(url, "image");
                 _onContentChanged(_contentController.text);
               }
             }
           });
        }
        return; 
      } catch (e) {
        debugPrint("粘贴图片失败: $e");
        setState(() => _isLoading = false);
      }
    }

    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
         _insertText(text);
      }
    }
  }

  // ================= 拖拽逻辑 =================

  Future<void> _handleDrop(List<XFile> files) async {
    for (var xfile in files) {
      final name = xfile.name.toLowerCase();
      if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.gif')) {
        setState(() => _isLoading = true);
        final bytes = await xfile.readAsBytes();
        final url = await _uploadImageBytes(bytes, xfile.name);
        setState(() => _isLoading = false);
        
        if (url != null) {
          _insertImageMarkdown(url, xfile.name);
          _onContentChanged(_contentController.text);
        }
      }
    }
  }

  // ================= 网络上传 =================

  Future<String?> _uploadImageBytes(Uint8List bytes, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppService().baseUrl}/upload'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename)
      );
      final res = await request.send().timeout(const Duration(seconds: 20));

      final respStr = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        final json = jsonDecode(respStr);
        final rawUrl = (json['url'] ?? '').toString();
        if (rawUrl.isEmpty) return null;
        return AppService().resolveMediaUrl(rawUrl);
      }

      // Surface server error (don't silently fallback to placeholder)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败：${res.statusCode} $respStr')),
        );
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败：$e')),
        );
      }
    }
    return null;
  }

  // ================= 编辑器辅助 =================

  void _insertImageMarkdown(String url, String alt) {
    _insertText("\n![$alt]($url)\n");
  }

  void _insertText(String content) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    int start = selection.start;
    int end = selection.end;

    if (start < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, content);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + content.length),
    );
    _previewNotifier.value = newText;
  }
  
  void _wrapSelection(String prefix, String suffix, {String defaultSelection = ""}) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start < 0 ? text.length : selection.start;
    int end = selection.end < 0 ? text.length : selection.end;
    
    String selectedText = text.substring(start, end);
    if (selectedText.isEmpty) selectedText = defaultSelection;
    
    String content = "$prefix$selectedText$suffix";
    
    final newText = text.replaceRange(start, end, content);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + prefix.length + selectedText.length + suffix.length),
    );
    _previewNotifier.value = newText;
  }

  // ================= 提交 =================
  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("标题不能为空")));
      return;
    }
    setState(() => _isLoading = true);
    final success = await MockService().publishArticle(
      _titleController.text.trim(),
      _contentController.text,
      widget.article?.id,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      return;
    }

    final err = AppService().lastError ?? '发布失败，请查看后端日志';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  // ================= UI 构建 =================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final toolbarColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F9FB);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handlePaste,
      },
      child: DropTarget(
        onDragDone: (detail) => _handleDrop(detail.files),
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: _buildModernAppBar(isDark),
          body: Column(
            children: [
              if (_mode != EditorMode.preview) _buildToolbar(toolbarColor, isDark),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              Expanded(
                child: Stack(
                  children: [
                    _buildBody(isDark),
                    if (_isDragging)
                      Container(
                        color: Colors.blue.withOpacity(0.2),
                        alignment: Alignment.center,
                        child: const Text("释放插入图片", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                    if (_isLoading)
                      Container(
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black54),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: const Text("文档编辑", style: TextStyle(fontSize: 14, color: Colors.grey)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: ToggleButtons(
            isSelected: [_mode == EditorMode.edit, _mode == EditorMode.split, _mode == EditorMode.preview],
            onPressed: (index) => setState(() => _mode = EditorMode.values[index]),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 30, minWidth: 40),
            color: Colors.grey,
            selectedColor: Colors.blue,
            fillColor: Colors.blue.withOpacity(0.1),
            children: const [
              Icon(Icons.edit_note, size: 18),
              Icon(Icons.vertical_split, size: 18),
              Icon(Icons.visibility, size: 18),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF26B96C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("发布"),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_mode) {
      case EditorMode.edit: return _buildEditorArea(isDark);
      case EditorMode.preview: return _buildPreviewArea(isDark);
      default: return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildEditorArea(isDark)),
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(child: _buildPreviewArea(isDark)),
        ],
      );
    }
  }

  Widget _buildEditorArea(bool isDark) {
    return Container(
      color: isDark ? Colors.black26 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: "请输入标题", border: InputBorder.none),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _contentController,
              scrollController: _editScrollController,
              onChanged: _onContentChanged,
              decoration: const InputDecoration(hintText: "开始写作... (Ctrl+V 粘贴图片)", border: InputBorder.none),
              maxLines: null,
              expands: true,
              style: TextStyle(fontSize: 16, height: 1.6, fontFamily: isDark ? null : 'Georgia'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252526) : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(32),
      child: ValueListenableBuilder<String>(
        valueListenable: _previewNotifier,
        builder: (context, content, _) {
          if (content.isEmpty && _titleController.text.isEmpty) {
             return const Center(child: Text("暂无内容", style: TextStyle(color: Colors.grey)));
          }
          return YuqueMarkdownView(
            data: "# ${_titleController.text}\n\n$content",
            tocController: _tocController,
            padding: EdgeInsets.zero,
          );
        },
      ),
    );
  }

  Widget _buildToolbar(Color bgColor, bool isDark) {
     return Container(
      height: 48,
      width: double.infinity,
      color: bgColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ToolBtn(icon: Icons.format_bold, tooltip: "加粗", onTap: () => _wrapSelection("**", "**")),
          _ToolBtn(icon: Icons.format_italic, tooltip: "斜体", onTap: () => _wrapSelection("*", "*")),
          _ToolBtn(icon: Icons.strikethrough_s, tooltip: "删除线", onTap: () => _wrapSelection("~~", "~~")),
          const _ToolDivider(),
          _ToolBtn(icon: Icons.title, tooltip: "标题 1", onTap: () => _wrapSelection("\n# ", "")),
          _ToolBtn(icon: Icons.format_size, tooltip: "标题 2", onTap: () => _wrapSelection("\n## ", "")),
          _ToolBtn(icon: Icons.format_list_bulleted, tooltip: "无序列表", onTap: () => _wrapSelection("\n- ", "")),
          _ToolBtn(icon: Icons.check_box_outlined, tooltip: "任务列表", onTap: () => _wrapSelection("\n- [ ] ", "")),
          const _ToolDivider(),
          _ToolBtn(icon: Icons.code, tooltip: "代码块", onTap: () => _wrapSelection("\n```dart\n", "\n```\n")), 
          _ToolBtn(icon: Icons.link, tooltip: "链接", onTap: () => _wrapSelection("[", "](url)")),
          _ToolBtn(icon: Icons.image_outlined, tooltip: "图片", onTap: () => _wrapSelection("![Alt](", ")")),
          const _ToolDivider(),
          _ToolBtn(icon: Icons.table_chart_outlined, tooltip: "表格", onTap: () => _wrapSelection("\n| A | B |\n|---|---|\n| 1 | 2 |", "")),
          _ToolBtn(icon: Icons.functions, tooltip: "数学公式", onTap: () => _wrapSelection("\$\$", "\$\$")), 
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon, size: 20, color: Colors.grey[600]), tooltip: tooltip, onPressed: onTap, splashRadius: 20);
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), width: 1, color: Colors.black12);
  }
}