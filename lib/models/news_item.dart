
class NewsItem {
  final String id, category, title, description, content, imageUrl, time;
  final DateTime? publishedAt;
  final bool breaking;

  const NewsItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.content,
    required this.imageUrl,
    required this.time,
    this.publishedAt,
    this.breaking = false,
  });

  factory NewsItem.fromMap(String id, Map<String, dynamic> m) {
    final p = m['publishedAt'];
    return NewsItem(
      id: id,
      category: m['category'] ?? '',
      title: m['title'] ?? '',
      description: m['description'] ?? '',
      content: m['content'] ?? '',
      imageUrl: m['imageUrl'] ?? '',
      time: m['time'] ?? '',
      publishedAt: p?.toDate(),
      breaking: m['breaking'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'category': category,
    'title': title,
    'description': description,
    'content': content,
    'imageUrl': imageUrl,
    'time': time,
    'publishedAt': publishedAt,
    'breaking': breaking,
  };
}
