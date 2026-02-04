// lib/services/web_helpers_web.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// 仅在 Web 端执行的注册逻辑
void registerViewFactory(String viewId, String url) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.height = '100%'
      ..style.width = '100%',
  );
}