// lib/pages/editor_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ✅ TOC controller (from markdown_widget)
import 'package:markdown_widget/markdown_widget.dart';
// ✅ Drag & drop support
import 'package:desktop_drop/desktop_drop.dart';
// ✅ File picker support
import 'package:image_picker/image_picker.dart';
// ✅ HTTP
import 'package:http/http.dart' as http;
// ✅ Clipboard (images + text)
import 'package:super_clipboard/super_clipboard.dart';

import '../services/mock_service.dart';
import '../widgets/yuque_markdown_view.dart';

// 编辑器视图模式：单页（源码） / 双页（源码+预览） / 实时（所见即所得风格的“高亮编辑”）
enum EditorMode { edit, split, live }

class EditorPage extends StatefulWidget {
  final Article? article;
  const EditorPage({super.key, this.article});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _titleController;
  late final MarkdownEditingController _contentController;

  // 编辑区滚动
  final ScrollController _editScrollController = ScrollController();

  // ✅ 预览防抖与通知（只在双页模式启用，减少卡顿）
  late final ValueNotifier<String> _previewNotifier;
  Timer? _previewDebounce;

  // 状态
  EditorMode _mode = EditorMode.split;
  bool _isLoading = false;
  bool _isDragging = false;

  // 仅详情页会用 TOC；编辑预览为了性能默认不生成 TOC
  final TocController _tocController = TocController();

  // 保存/草稿
  String? _editingId; // draft id OR article id
  bool _isSaving = false;
  late final ValueNotifier<String> _saveStatus;

  @override
  void initState() {
    super.initState();
    _editingId = widget.article?.id;

    _titleController = TextEditingController(text: widget.article?.title ?? "");
    _contentController = MarkdownEditingController(text: widget.article?.content ?? "");
    _contentController.highlightEnabled = (_mode == EditorMode.live);

    _previewNotifier = ValueNotifier(_contentController.text);
    _saveStatus = ValueNotifier(widget.article == null ? "未保存" : ""); // 空表示不提示

    // 标题变化：标记未保存 &（双页）更新预览
    _titleController.addListener(() {
      _saveStatus.value = "未保存";
      if (_mode == EditorMode.split) _schedulePreviewUpdate(immediate: false);
    });

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
    final full = await MockService().getArticleById(
      art.id,
      includeDraft: (art.status == 'draft'),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载文章内容失败')),
      );
      return;
    }

    _editingId = full.id;
    _titleController.text = full.title;
    _contentController.text = full.content;

    // 只有双页模式才推预览
    if (_mode == EditorMode.split) {
      _previewNotifier.value = full.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _editScrollController.dispose();
    _previewNotifier.dispose();
    _previewDebounce?.cancel();
    _tocController.dispose();
    _saveStatus.dispose();
    super.dispose();
  }

  // ================= 预览防抖（仅双页） =================

  void _onContentChanged(String text) {
    _saveStatus.value = "未保存";
    if (_mode == EditorMode.split) {
      _schedulePreviewUpdate(immediate: false);
    }
  }

  void _schedulePreviewUpdate({required bool immediate}) {
    if (immediate) {
      _previewNotifier.value = _contentController.text;
      return;
    }
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (_mode != EditorMode.split) return;
      _previewNotifier.value = _contentController.text;
    });
  }

  void _setMode(EditorMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);

    // Toggle “live highlight” only in live mode.
    final shouldHighlight = (mode == EditorMode.live);
    _contentController.highlightEnabled = shouldHighlight;

    // When switching into split, push current text once.
    if (mode == EditorMode.split) {
      _previewNotifier.value = _contentController.text;
    }
  }

  // ================= 粘贴逻辑（仿语雀：图片优先） =================

  Future<void> _handlePaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final reader = await clipboard.read();

    if (reader.canProvide(Formats.png) || reader.canProvide(Formats.jpeg) || reader.canProvide(Formats.webp)) {
      setState(() => _isLoading = true);

      Future<void> readFile(dynamic format, String defaultName) async {
        final ok = reader.getFile(format, (file) async {
          final bytes = await file.readAll();
          final filename = file.fileName ?? defaultName;
          final url = await _uploadImageBytes(bytes, filename);
          if (!mounted) return;
          setState(() => _isLoading = false);
          if (url != null) {
            _insertImageMarkdown(url, "image");
            _onContentChanged(_contentController.text);
          }
        });
        if (ok == null) return;
      }

      try {
        await readFile(Formats.png, "pasted_image.png");
        await readFile(Formats.jpeg, "pasted_image.jpg");
        await readFile(Formats.webp, "pasted_image.webp");
      } catch (e) {
        debugPrint("粘贴图片失败: $e");
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        _insertText(text);
        _onContentChanged(_contentController.text);
      }
    }
  }

  // ================= 拖拽插入图片 =================

  Future<void> _handleDrop(List<XFile> files) async {
    for (final xfile in files) {
      final name = xfile.name.toLowerCase();
      if (name.endsWith('.png') ||
          name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.gif') ||
          name.endsWith('.webp')) {
        setState(() => _isLoading = true);
        final bytes = await xfile.readAsBytes();
        final url = await _uploadImageBytes(bytes, xfile.name);
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (url != null) {
          _insertImageMarkdown(url, xfile.name);
          _onContentChanged(_contentController.text);
        }
      }
    }
  }

  // ================= 上传图片 =================

  Future<String?> _uploadImageBytes(Uint8List bytes, String filename) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppService().baseUrl}/upload'),
      );
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final res = await request.send().timeout(const Duration(seconds: 20));

      final respStr = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        final json = jsonDecode(respStr);
        final rawUrl = (json['url'] ?? '').toString();
        if (rawUrl.isEmpty) return null;
        return AppService().resolveMediaUrl(rawUrl);
      }

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

  // ================= 编辑辅助 =================

  void _insertImageMarkdown(String url, String alt) => _insertText("\n![$alt]($url)\n");

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

    // split 模式立即同步一次（不等防抖）能让粘贴图片体验更像语雀
    if (_mode == EditorMode.split) {
      _previewNotifier.value = newText;
    }
  }

  void _wrapSelection(
    String prefix,
    String suffix, {
    String defaultSelection = "",
  }) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start < 0 ? text.length : selection.start;
    int end = selection.end < 0 ? text.length : selection.end;

    String selectedText = text.substring(start, end);
    if (selectedText.isEmpty) selectedText = defaultSelection;

    final content = "$prefix$selectedText$suffix";

    final newText = text.replaceRange(start, end, content);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + prefix.length + selectedText.length + suffix.length,
      ),
    );

    if (_mode == EditorMode.split) _previewNotifier.value = newText;
  }

  // ================= 保存（Ctrl+S） =================

  Future<void> _saveDraft({bool showToast = true}) async {
    if (_isSaving) return;

    final app = AppService();
    if (!app.isLoggedIn) {
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先登录")));
      }
      return;
    }
    if (!app.isAdmin) {
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("只有管理员可以保存草稿/编辑文章")));
      }
      return;
    }

    final title = _titleController.text.trim().isEmpty ? "未命名文档" : _titleController.text.trim();
    final content = _contentController.text;

    setState(() => _isSaving = true);
    _saveStatus.value = "保存中…";

    final id = await MockService().saveArticle(title: title, content: content, id: _editingId);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (id != null && id.isNotEmpty) {
      _editingId = id;
      final now = TimeOfDay.now();
      _saveStatus.value = "已保存 ${now.format(context)}";
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已保存并上传")));
      }
      return;
    }

    _saveStatus.value = "保存失败";
    final err = AppService().lastError ?? "保存失败，请查看后端日志";
    if (showToast) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // ================= 发布 =================

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("标题不能为空")));
      return;
    }

    setState(() => _isLoading = true);

    final success = await MockService().publishArticle(
      _titleController.text.trim(),
      _contentController.text,
      _editingId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context);
      return;
    }

    final err = AppService().lastError ?? '发布失败，请查看后端日志';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final toolbarColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F9FB);

    return CallbackShortcuts(
      bindings: {
        // Paste image / text
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handlePaste,

        // Save draft (Ctrl+S)
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _saveDraft(showToast: true),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => _saveDraft(showToast: true),
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
              _buildToolbar(toolbarColor, isDark),
              const Divider(height: 1, thickness: 1, color: Colors.black12),
              Expanded(
                child: Stack(
                  children: [
                    _buildBody(isDark),
                    if (_isDragging)
                      Container(
                        color: Colors.blue.withOpacity(0.18),
                        alignment: Alignment.center,
                        child: const Text(
                          "释放插入图片",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
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
    final statusChip = ValueListenableBuilder<String>(
      valueListenable: _saveStatus,
      builder: (context, s, _) {
        if (s.isEmpty) return const SizedBox.shrink();
        final isSaving = _isSaving;
        return Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSaving ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSaving ? Colors.orange.withOpacity(0.25) : Colors.green.withOpacity(0.20)),
          ),
          child: Text(
            s,
            style: TextStyle(
              fontSize: 12,
              color: isSaving ? Colors.orange.shade700 : Colors.green.shade700,
            ),
          ),
        );
      },
    );

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
        // 保存状态
        statusChip,

        // 视图模式：单页 / 双页 / 实时
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: ToggleButtons(
            isSelected: [_mode == EditorMode.edit, _mode == EditorMode.split, _mode == EditorMode.live],
            onPressed: (index) => _setMode(EditorMode.values[index]),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 30, minWidth: 58),
            color: Colors.grey,
            selectedColor: Colors.blue,
            fillColor: Colors.blue.withOpacity(0.10),
            children: const [
              Text('单页', style: TextStyle(fontSize: 12)),
              Text('双页', style: TextStyle(fontSize: 12)),
              Text('预览', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),

        // 保存按钮（也方便 web 上 Ctrl+S 被浏览器拦截时）
        Padding(
          padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _saveDraft(showToast: true),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text("保存", style: TextStyle(fontSize: 12)),
          ),
        ),

        // 发布按钮
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF26B96C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text("发布"),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_mode) {
      case EditorMode.edit:
        return _buildEditorArea(isDark, highlight: false);
      case EditorMode.live:
        return _buildEditorArea(isDark, highlight: true);
      case EditorMode.split:
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildEditorArea(isDark, highlight: false)),
            const VerticalDivider(width: 1, color: Colors.black12),
            Expanded(child: _buildPreviewArea(isDark)),
          ],
        );
    }
  }

  Widget _buildEditorArea(bool isDark, {required bool highlight}) {
    // 在“实时”模式下启用高亮（更像“所见即所得”），其它模式关闭以提升性能
    _contentController.highlightEnabled = highlight;

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
              decoration: const InputDecoration(
                hintText: "开始写作…（Ctrl+V 粘贴图片，Ctrl+S 保存）",
                border: InputBorder.none,
              ),
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              // ✅ 一些小优化：减少 Web/桌面输入时的额外开销
              enableSuggestions: false,
              autocorrect: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                fontFamily: isDark ? null : 'Georgia',
              ),
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
            // 编辑预览：性能优先，不开启 selectable，也不做 toc
            selectable: false,
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _ToolBtn(icon: Icons.format_bold, tooltip: "加粗", onTap: () => _wrapSelection("**", "**")),
          _ToolBtn(icon: Icons.format_italic, tooltip: "斜体", onTap: () => _wrapSelection("*", "*")),
          _ToolBtn(icon: Icons.strikethrough_s, tooltip: "删除线", onTap: () => _wrapSelection("~~", "~~")),
          _ToolBtn(icon: Icons.format_underline, tooltip: "下划线", onTap: () => _wrapSelection("[u]", "[/u]")),
          const _ToolDivider(),

          _ToolBtn(icon: Icons.title, tooltip: "标题 1", onTap: () => _wrapSelection("\n# ", "")),
          _ToolBtn(icon: Icons.format_size, tooltip: "标题 2", onTap: () => _wrapSelection("\n## ", "")),
          _ToolBtn(icon: Icons.format_list_bulleted, tooltip: "无序列表", onTap: () => _wrapSelection("\n- ", "")),
          _ToolBtn(icon: Icons.check_box_outlined, tooltip: "任务列表", onTap: () => _wrapSelection("\n- [ ] ", "")),
          const _ToolDivider(),

          _ToolBtn(icon: Icons.code, tooltip: "代码块", onTap: () => _wrapSelection("\n```dart\n", "\n```\n")),
          _ToolBtn(icon: Icons.link, tooltip: "链接", onTap: () => _wrapSelection("[", "](url)", defaultSelection: "链接文字")),
          _ToolBtn(icon: Icons.image_outlined, tooltip: "图片", onTap: () => _wrapSelection("![Alt](", ")", defaultSelection: "url")),
          const _ToolDivider(),

          _ToolBtn(icon: Icons.table_chart_outlined, tooltip: "表格", onTap: () => _wrapSelection("\n| A | B |\n|---|---|\n| 1 | 2 |\n", "")),
          _ToolBtn(icon: Icons.functions, tooltip: "数学公式", onTap: () => _wrapSelection("\$\$", "\$\$", defaultSelection: "E=mc^2")),
          const _ToolDivider(),

          // ✅ Yuque-ish: 文字颜色 / 背景色 / 字号
          _ColorMenuBtn(
            tooltip: "文字颜色",
            icon: Icons.format_color_text,
            onPick: (hex) => _wrapSelection("[color=$hex]", "[/color]", defaultSelection: "彩色文字"),
          ),
          _ColorMenuBtn(
            tooltip: "背景高亮",
            icon: Icons.format_color_fill,
            onPick: (hex) => _wrapSelection("[bg=$hex]", "[/bg]", defaultSelection: "高亮文字"),
          ),
          _SizeMenuBtn(
            tooltip: "字号",
            icon: Icons.text_fields,
            onPick: (size) => _wrapSelection("[size=$size]", "[/size]", defaultSelection: "大字"),
          ),
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
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.grey[600]),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      width: 1,
      color: Colors.black12,
    );
  }
}

String _colorToHex(Color c) {
  // ARGB -> RRGGBB
  final hex = c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  return '#$hex';
}

class _ColorMenuBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final void Function(String hex) onPick;

  const _ColorMenuBtn({required this.tooltip, required this.icon, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final presets = <Color>[
      const Color(0xFFEF4444), // red
      const Color(0xFFF97316), // orange
      const Color(0xFFEAB308), // amber
      const Color(0xFF22C55E), // green
      const Color(0xFF06B6D4), // cyan
      const Color(0xFF3B82F6), // blue
      const Color(0xFF8B5CF6), // purple
      const Color(0xFF111827), // almost black
    ];

    return PopupMenuButton<Color>(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: Colors.grey[600]),
      itemBuilder: (context) {
        return presets
            .map(
              (c) => PopupMenuItem<Color>(
                value: c,
                child: Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Text(_colorToHex(c)),
                  ],
                ),
              ),
            )
            .toList();
      },
      onSelected: (c) => onPick(_colorToHex(c)),
    );
  }
}

class _SizeMenuBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final void Function(int size) onPick;

  const _SizeMenuBtn({required this.tooltip, required this.icon, required this.onPick});

  @override
  Widget build(BuildContext context) {
    const sizes = <int>[12, 14, 16, 18, 20, 24, 28];

    return PopupMenuButton<int>(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: Colors.grey[600]),
      itemBuilder: (context) {
        return sizes
            .map(
              (s) => PopupMenuItem<int>(
                value: s,
                child: Text('字号 $s'),
              ),
            )
            .toList();
      },
      onSelected: (s) => onPick(s),
    );
  }
}

// ===========================
// Live preview-ish editing controller (lightweight markdown highlighting)
// ===========================

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({String? text}) : super(text: text);

  /// Turn on/off syntax highlighting (only in EditorMode.live).
  bool highlightEnabled = false;

  /// If content is very large, highlighting can be expensive on Flutter Web.
  /// We'll auto-disable when exceeding this threshold.
  static const int kMaxHighlightChars = 40000;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final src = text;

    if (!highlightEnabled || src.length > kMaxHighlightChars) {
      return TextSpan(style: baseStyle, text: src);
    }

    final theme = Theme.of(context);
    final spans = <InlineSpan>[];

    final lines = src.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Headings: # / ## / ###
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final content = headingMatch.group(2) ?? '';
        final fs = switch (level) {
          1 => 26.0,
          2 => 22.0,
          3 => 18.0,
          4 => 16.0,
          5 => 15.0,
          _ => 14.0,
        };
        spans.add(TextSpan(
          text: '${headingMatch.group(1)} ',
          style: baseStyle.copyWith(color: theme.hintColor),
        ));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontSize: fs, fontWeight: FontWeight.w700),
        ));
      } else {
        spans.addAll(_inlineHighlight(line, baseStyle, theme));
      }

      if (i != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  List<InlineSpan> _inlineHighlight(String line, TextStyle base, ThemeData theme) {
    // Order matters: more specific first.
    final patterns = <_PatternRule>[
      _PatternRule(
        name: 'color',
        reg: RegExp(r'\[color=(#[0-9a-fA-F]{6})\]([^\n]+?)\[/color\]'),
        builder: (m) {
          final hex = m.group(1) ?? '';
          final content = m.group(2) ?? '';
          final c = _tryParseHex(hex) ?? base.color;
          return [
            TextSpan(text: '[color=$hex]', style: base.copyWith(color: theme.hintColor)),
            TextSpan(text: content, style: base.copyWith(color: c)),
            TextSpan(text: '[/color]', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
      _PatternRule(
        name: 'bg',
        reg: RegExp(r'\[bg=(#[0-9a-fA-F]{6})\]([^\n]+?)\[/bg\]'),
        builder: (m) {
          final hex = m.group(1) ?? '';
          final content = m.group(2) ?? '';
          final bg = _tryParseHex(hex);
          return [
            TextSpan(text: '[bg=$hex]', style: base.copyWith(color: theme.hintColor)),
            TextSpan(
              text: content,
              style: base.copyWith(backgroundColor: (bg ?? Colors.yellow).withOpacity(0.35)),
            ),
            TextSpan(text: '[/bg]', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
      _PatternRule(
        name: 'size',
        reg: RegExp(r'\[size=(\d{1,2})\]([^\n]+?)\[/size\]'),
        builder: (m) {
          final s = m.group(1) ?? '';
          final content = m.group(2) ?? '';
          final fs = int.tryParse(s) ?? 16;
          return [
            TextSpan(text: '[size=$fs]', style: base.copyWith(color: theme.hintColor)),
            TextSpan(text: content, style: base.copyWith(fontSize: fs.toDouble())),
            TextSpan(text: '[/size]', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
      _PatternRule(
        name: 'underline',
        reg: RegExp(r'\[u\]([^\n]+?)\[/u\]'),
        builder: (m) {
          final content = m.group(1) ?? '';
          return [
            TextSpan(text: '[u]', style: base.copyWith(color: theme.hintColor)),
            TextSpan(text: content, style: base.copyWith(decoration: TextDecoration.underline)),
            TextSpan(text: '[/u]', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
      _PatternRule(
        name: 'bold',
        reg: RegExp(r'\*\*(.+?)\*\*'),
        builder: (m) {
          final content = m.group(1) ?? '';
          return [
            TextSpan(text: '**', style: base.copyWith(color: theme.hintColor)),
            TextSpan(text: content, style: base.copyWith(fontWeight: FontWeight.bold)),
            TextSpan(text: '**', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
      _PatternRule(
        name: 'strike',
        reg: RegExp(r'~~(.+?)~~'),
        builder: (m) {
          final content = m.group(1) ?? '';
          return [
            TextSpan(text: '~~', style: base.copyWith(color: theme.hintColor)),
            TextSpan(text: content, style: base.copyWith(decoration: TextDecoration.lineThrough)),
            TextSpan(text: '~~', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
      _PatternRule(
        name: 'code',
        reg: RegExp(r'`(.+?)`'),
        builder: (m) {
          final content = m.group(1) ?? '';
          return [
            TextSpan(text: '`', style: base.copyWith(color: theme.hintColor)),
            TextSpan(
              text: content,
              style: base.copyWith(
                fontFamily: 'monospace',
                backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              ),
            ),
            TextSpan(text: '`', style: base.copyWith(color: theme.hintColor)),
          ];
        },
      ),
    ];

    final out = <InlineSpan>[];
    int index = 0;

    while (index < line.length) {
      _PatternMatch? best;
      for (final rule in patterns) {
        final m = rule.reg.firstMatch(line.substring(index));
        if (m == null) continue;
        final start = index + m.start;
        final end = index + m.end;
        if (best == null || start < best.start) {
          best = _PatternMatch(start: start, end: end, match: m, rule: rule, localOffset: index);
        }
      }

      if (best == null) {
        out.add(TextSpan(text: line.substring(index), style: base));
        break;
      }

      if (best.start > index) {
        out.add(TextSpan(text: line.substring(index, best.start), style: base));
      }

      // Recreate the match over the original line segment.
      final local = line.substring(best.localOffset);
      final m = best.rule.reg.firstMatch(local)!;

      out.addAll(best.rule.builder(m));
      index = best.end;
    }

    return out;
  }

  Color? _tryParseHex(String hex) {
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    final v = int.parse(hex.substring(1), radix: 16);
    return Color(0xFF000000 | v);
  }
}

class _PatternRule {
  final String name;
  final RegExp reg;
  final List<InlineSpan> Function(Match m) builder;
  _PatternRule({required this.name, required this.reg, required this.builder});
}

class _PatternMatch {
  final int start;
  final int end;
  final Match match;
  final _PatternRule rule;
  final int localOffset;
  _PatternMatch({required this.start, required this.end, required this.match, required this.rule, required this.localOffset});
}
