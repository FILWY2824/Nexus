// lib/models/data_model.dart

/// 用户角色枚举
enum UserRole {
  guest, // 游客
  admin, // 管理员
}

/// 用户模型
class User {
  final String email;
  final String name;
  final UserRole role;

  User({required this.email, required this.name, required this.role});
}

/// 博客文章模型
class BlogPost {
  final String id;
  final String title;
  final String summary;
  final String author;
  final DateTime publishDate;
  int views;

  BlogPost({
    required this.id,
    required this.title,
    required this.summary,
    required this.author,
    required this.publishDate,
    this.views = 0,
  });
}