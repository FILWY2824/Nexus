// lib/pages/email_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

// 【核心修复】条件导入：
// 编译 Web 版时 -> 引入 web_helpers_web.dart (包含 dart:html)
// 编译 Android 版时 -> 引入 web_helpers_stub.dart (空文件)
// ✅ 替换为新的绝对路径引用：
import 'package:dashboard/shared/services/web_helpers_stub.dart' 
    if (dart.library.html) 'package:dashboard/shared/services/web_helpers_web.dart';

class EmailPage extends StatefulWidget {
  const EmailPage({super.key});

  @override
  State<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  final String targetUrl = "https://mail.officecy.dpdns.org/";
  final String viewId = "email-web-view";

  WebViewController? _mobileController;

  @override
  void initState() {
    super.initState();
    
    if (kIsWeb) {
      // 1. Web 端初始化
      // 调用那个隔离出来的函数，避免直接引用 dart:html
      registerViewFactory(viewId, targetUrl);
    } else {
      // 2. 手机端初始化 (Android/iOS)
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        
        _mobileController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(targetUrl));
      }
    }
  }

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(targetUrl);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具条
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: Row(
            children: [
              const Icon(Icons.security, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              const Text("安全连接: mail.officecy.dpdns.org", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              TextButton.icon(
                onPressed: _launchUrl,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text("浏览器打开"),
              ),
            ],
          ),
        ),
        
        // 内容区
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    // Web 端显示 iframe
    if (kIsWeb) {
      return HtmlElementView(viewType: viewId);
    }
    
    // 手机端显示 WebView
    if (_mobileController != null) {
      return WebViewWidget(controller: _mobileController!);
    }

    // 桌面端 (Windows) 显示占位符
    return _buildNonWebPlaceholder();
  }

  Widget _buildNonWebPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("桌面端暂不支持内嵌，请跳转浏览", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _launchUrl,
            child: const Text("跳转打开邮箱"),
          )
        ],
      ),
    );
  }
}