
class NewsItem {
  final String id, category, title, description, content, imageUrl, time;
  final List<String> imageUrls;
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
    this.imageUrls = const [],
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
      imageUrls: m['imageUrls'] is List
          ? List<String>.from(m['imageUrls'])
          : ((m['imageUrl'] ?? '').toString().isNotEmpty
              ? <String>[(m['imageUrl'] ?? '').toString()]
              : <String>[]),
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
    'imageUrls': imageUrls,
    'time': time,
    'publishedAt': publishedAt,
    'breaking': breaking,
  };
}
