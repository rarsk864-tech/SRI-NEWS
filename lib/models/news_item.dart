
class NewsItem {
  final String id, category, title, description, content, imageUrl, time;
  final List<String> imageUrls;
  final DateTime? publishedAt;
  final bool breaking;
  final int titleColor;
  final int matterColor;

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
    this.titleColor = 0xFF171313,
    this.matterColor = 0xFF6C6767,
  });

  static int _readColor(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return fallback;
    var hex = text.toLowerCase().replaceFirst('#', '');
    if (hex.startsWith('0x')) hex = hex.substring(2);
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;
    return hex.length <= 6 ? (0xFF000000 | parsed) : parsed;
  }

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
      titleColor: _readColor(m['titleColor'] ?? m['titleColorHex'], 0xFF171313),
      matterColor: _readColor(m['matterColor'] ?? m['matterColorHex'], 0xFF6C6767),
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
    'titleColor': titleColor,
    'matterColor': matterColor,
  };
}
