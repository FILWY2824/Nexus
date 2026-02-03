// lib/pages/email_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 需要在 pubspec.yaml 添加 url_launcher

class EmailPage extends StatelessWidget {
  const EmailPage({super.key});

  // 你的外部服务地址
  final String emailServiceUrl = "https://mail.officecy.dpdns.org/";

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(emailServiceUrl);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            "临时邮箱管理系统",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "该服务托管于外部安全节点",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _launchUrl,
            icon: const Icon(Icons.open_in_new),
            label: const Text("前往邮箱管理后台 (mail.officecy.dpdns.org)"),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            ),
          ),
        ],
      ),
    );
  }
}