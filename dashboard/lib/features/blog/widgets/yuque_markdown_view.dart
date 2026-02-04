import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

import 'package:dashboard/shared/services/mock_service.dart';

/// A Yuque-like Markdown renderer:
/// - GitHub-flavored Markdown
/// - LaTeX ($...$ / $$...$$) rendered by flutter_math_fork
/// - Yuque-ish rich text extensions:
///   - [color=#RRGGBB]text[/color]
///   - [bg=#RRGGBB]text[/bg]
///   - [size=20]text[/size]
///   - [u]text[/u]
/// - Better image UX: loading placeholder + click-to-zoom
///
/// Usage:
///   YuqueMarkdownView(data: markdown)
class YuqueMarkdownView extends StatelessWidget {
  const YuqueMarkdownView({
    super.key,
    required this.data,
    this.tocController,
    this.padding,
    this.selectable = true,
  });

  final String data;
  final TocController? tocController;
  final EdgeInsetsGeometry? padding;
  final bool selectable;

  static final MarkdownGenerator _generator = MarkdownGenerator(
    extensionSet: m.ExtensionSet.gitHubFlavored,
    // Enable LaTeX + Yuque-ish inline styles.
    inlineSyntaxList: [
      LatexSyntax(),
      YuqueColorSyntax(),
      YuqueBgSyntax(),
      YuqueSizeSyntax(),
      YuqueUnderlineSyntax(),
    ],
    generators: [
      latexGenerator,
      yuqueStyleGenerator,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

    final config = baseConfig.copy(
      configs: [
        // Code highlighting theme
        PreConfig(theme: isDark ? draculaTheme : githubTheme),

        // Better image loading + tap to view
        ImgConfig(
          builder: (url, attributes) => _YuqueImage(url: url, attributes: attributes),
          errorBuilder: (url, alt, error) => _YuqueImageError(url: url, alt: alt, error: error),
        ),
      ],
    );

    return RepaintBoundary(
      child: MarkdownWidget(
        data: data,
        tocController: tocController,
        selectable: selectable,
        padding: padding,
        config: config,
        markdownGenerator: _generator,
      ),
    );
  }
}

// ------------------------
// LaTeX support (markdown_widget custom tag)
// ------------------------

const String _latexTag = 'latex';

/// ⚠️ Note: Must NOT be `const` because it captures a closure.
final SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) => LatexNode(e.attributes, e.textContent, config),
);

/// Parse $...$ (inline) and $$...$$ (block).
///
/// Notes:
/// - This is a pragmatic regex-based parser; it intentionally stays lightweight.
/// - Escaped dollars (\$) are not treated as math delimiters.
class LatexSyntax extends m.InlineSyntax {
  LatexSyntax()
      : super(
          // 1) $$...$$  (allow multiline)
          // 2) $...$    (single-line)
          // Keep it simple & compatible with Flutter Web RegExp.
          r'(\$\$[\s\S]+?\$\$)|(\$.+?\$)',
        );

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final input = match.input;
    final matchValue = input.substring(match.start, match.end);

    String content = '';
    bool isInline = true;

    const blockSyntax = r'$$';
    const inlineSyntax = r'$';

    if (matchValue.startsWith(blockSyntax) && matchValue.endsWith(blockSyntax) && matchValue != blockSyntax) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(inlineSyntax) && matchValue.endsWith(inlineSyntax) && matchValue != inlineSyntax) {
      content = matchValue.substring(1, matchValue.length - 1);
      isInline = true;
    }

    final el = m.Element.text(_latexTag, matchValue);
    el.attributes['content'] = content;
    el.attributes['isInline'] = '$isInline';
    parser.addNode(el);
    return true;
  }
}

class LatexNode extends SpanNode {
  LatexNode(this.attributes, this.textContent, this.config);

  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  @override
  InlineSpan build() {
    final content = attributes['content'] ?? '';
    final isInline = attributes['isInline'] == 'true';
    final style = parentStyle ?? config.p.textStyle;

    if (content.isEmpty) {
      return TextSpan(style: style, text: textContent);
    }

    final latex = Math.tex(
      content,
      mathStyle: isInline ? MathStyle.text : MathStyle.display,
      // Follow the markdown text style so it adapts to theme.
      textStyle: style,
      textScaleFactor: 1,
      onErrorFallback: (error) {
        return Text(
          textContent,
          style: style.copyWith(color: Colors.red),
        );
      },
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: isInline
          ? latex
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: latex),
            ),
    );
  }
}

// ------------------------
// Yuque-ish rich text extensions
// ------------------------

const String _yuqueStyleTag = 'yuque_style';

final SpanNodeGeneratorWithTag yuqueStyleGenerator = SpanNodeGeneratorWithTag(
  tag: _yuqueStyleTag,
  generator: (e, config, visitor) => YuqueStyleNode(e.attributes, e.textContent, config),
);

Color? _parseHexColor(String? hex, {Color? fallback}) {
  if (hex == null) return fallback;
  final s = hex.trim();
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return fallback;
  final v = int.parse(s.substring(1), radix: 16);
  return Color(0xFF000000 | v);
}

double? _parseFontSize(String? s, {double min = 10, double max = 48}) {
  if (s == null) return null;
  final n = int.tryParse(s.trim());
  if (n == null) return null;
  return n.clamp(min.toInt(), max.toInt()).toDouble();
}

/// [color=#RRGGBB]text[/color]
class YuqueColorSyntax extends m.InlineSyntax {
  YuqueColorSyntax() : super(r'\[color=(#[0-9a-fA-F]{6})\]([^\n]+?)\[/color\]');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final color = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    final el = m.Element.text(_yuqueStyleTag, match.group(0) ?? '');
    el.attributes['content'] = content;
    el.attributes['color'] = color;
    parser.addNode(el);
    return true;
  }
}

/// [bg=#RRGGBB]text[/bg]
class YuqueBgSyntax extends m.InlineSyntax {
  YuqueBgSyntax() : super(r'\[bg=(#[0-9a-fA-F]{6})\]([^\n]+?)\[/bg\]');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final bg = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    final el = m.Element.text(_yuqueStyleTag, match.group(0) ?? '');
    el.attributes['content'] = content;
    el.attributes['bg'] = bg;
    parser.addNode(el);
    return true;
  }
}

/// [size=20]text[/size]
class YuqueSizeSyntax extends m.InlineSyntax {
  YuqueSizeSyntax() : super(r'\[size=(\d{1,2})\]([^\n]+?)\[/size\]');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final size = match.group(1) ?? '';
    final content = match.group(2) ?? '';
    final el = m.Element.text(_yuqueStyleTag, match.group(0) ?? '');
    el.attributes['content'] = content;
    el.attributes['size'] = size;
    parser.addNode(el);
    return true;
  }
}

/// [u]text[/u]
class YuqueUnderlineSyntax extends m.InlineSyntax {
  YuqueUnderlineSyntax() : super(r'\[u\]([^\n]+?)\[/u\]');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final content = match.group(1) ?? '';
    final el = m.Element.text(_yuqueStyleTag, match.group(0) ?? '');
    el.attributes['content'] = content;
    el.attributes['u'] = 'true';
    parser.addNode(el);
    return true;
  }
}

class YuqueStyleNode extends SpanNode {
  YuqueStyleNode(this.attributes, this.textContent, this.config);

  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  @override
  InlineSpan build() {
    final raw = textContent;
    final content = (attributes['content'] ?? '').isNotEmpty ? (attributes['content'] ?? '') : raw;

    TextStyle style = parentStyle ?? config.p.textStyle;

    final color = _parseHexColor(attributes['color']);
    if (color != null) style = style.copyWith(color: color);

    final bg = _parseHexColor(attributes['bg']);
    if (bg != null) style = style.copyWith(backgroundColor: bg.withOpacity(0.35));

    final fs = _parseFontSize(attributes['size']);
    if (fs != null) style = style.copyWith(fontSize: fs);

    if (attributes['u'] == 'true') {
      style = style.copyWith(decoration: TextDecoration.underline);
    }

    return TextSpan(style: style, text: content);
  }
}

// ------------------------
// Better image UX
// ------------------------

class _YuqueImage extends StatelessWidget {
  const _YuqueImage({required this.url, required this.attributes});

  final String url;
  final Map<String, String> attributes;

  @override
  Widget build(BuildContext context) {
    final resolved = AppService().resolveMediaUrl(url);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showImageViewer(context, resolved),
            child: CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.contain,
              placeholder: (context, url) => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) {
                return _YuqueImageError(url: url, alt: attributes['alt'] ?? '', error: error);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showImageViewer(BuildContext context, String resolvedUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) {
                        return _YuqueImageError(url: url, alt: attributes['alt'] ?? '', error: error);
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YuqueImageError extends StatelessWidget {
  const _YuqueImageError({required this.url, required this.alt, required this.error});

  final String url;
  final String alt;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined),
          const SizedBox(height: 8),
          Text(
            alt.isNotEmpty ? '图片加载失败：$alt' : '图片加载失败',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
