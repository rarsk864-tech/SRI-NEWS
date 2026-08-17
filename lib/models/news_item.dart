import 'package:flutter/widgets.dart';

class MatterSegment {
  final String text;
  final int color;

  const MatterSegment({required this.text, required this.color});

  factory MatterSegment.fromMap(dynamic value, int fallback) {
    if (value is Map) {
      final text = (value['text'] ?? '').toString();
      final raw = value['color'] ?? value['colorHex'];
      return MatterSegment(text: text, color: _readColorValue(raw, fallback));
    }
    return MatterSegment(text: value?.toString() ?? '', color: fallback);
  }

  Map<String, dynamic> toMap() => {'text': text, 'color': color, 'colorHex': '#${color.toRadixString(16).padLeft(8, '0').substring(2)}'};
}

int _readColorValue(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return fallback;
  var hex = text.toLowerCase().replaceFirst('#', '');
  if (hex.startsWith('0x')) hex = hex.substring(2);
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return fallback;
  return hex.length <= 6 ? (0xFF000000 | parsed) : parsed;
}

List<MatterSegment> applyMatterColorSelection(
  String text,
  List<MatterSegment> current,
  TextSelection selection,
  int color,
  int fallbackColor,
) {
  if (!selection.isValid || selection.start == selection.end || text.isEmpty) {
    return current.isEmpty
        ? [MatterSegment(text: text, color: fallbackColor)]
        : current;
  }

  final rawStart = selection.start.clamp(0, text.length).toInt();
  final rawEnd = selection.end.clamp(0, text.length).toInt();
  final a = rawStart < rawEnd ? rawStart : rawEnd;
  final b = rawStart < rawEnd ? rawEnd : rawStart;

  final joined = current.map((e) => e.text).join();
  final base = (current.isEmpty || joined != text)
      ? [MatterSegment(text: text, color: fallbackColor)]
      : current;

  final result = <MatterSegment>[];
  var position = 0;

  for (final segment in base) {
    final segStart = position;
    final segEnd = position + segment.text.length;
    final length = segment.text.length;

    if (segStart >= b || segEnd <= a) {
      if (segment.text.isNotEmpty) result.add(segment);
      position = segEnd;
      continue;
    }

    final preEnd = (a - segStart).clamp(0, length).toInt();
    final midStart = (a - segStart).clamp(0, length).toInt();
    final midEnd = (b - segStart).clamp(0, length).toInt();
    final postStart = midEnd;

    if (preEnd > 0) {
      result.add(MatterSegment(
        text: segment.text.substring(0, preEnd),
        color: segment.color,
      ));
    }
    if (midEnd > midStart) {
      result.add(MatterSegment(
        text: segment.text.substring(midStart, midEnd),
        color: color,
      ));
    }
    if (postStart < length) {
      result.add(MatterSegment(
        text: segment.text.substring(postStart),
        color: segment.color,
      ));
    }

    position = segEnd;
  }

  final merged = <MatterSegment>[];
  for (final segment in result) {
    if (segment.text.isEmpty) continue;
    if (merged.isNotEmpty && merged.last.color == segment.color) {
      merged[merged.length - 1] = MatterSegment(
        text: merged.last.text + segment.text,
        color: segment.color,
      );
    } else {
      merged.add(segment);
    }
  }
  return merged.isEmpty
      ? [MatterSegment(text: text, color: color)]
      : merged;
}

class NewsItem {
  final String id, category, title, description, content, imageUrl, time;
  final List<String> imageUrls;
  final DateTime? publishedAt;
  final bool breaking;
  final int titleColor;
  final int matterColor;
  final List<MatterSegment> matterSegments;

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
    this.matterSegments = const [],
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
      matterSegments: m['matterSegments'] is List
          ? (m['matterSegments'] as List).map((e) => MatterSegment.fromMap(e, _readColor(m['matterColor'] ?? m['matterColorHex'], 0xFF6C6767))).where((e) => e.text.isNotEmpty).toList()
          : const [],
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
    'matterSegments': matterSegments.map((e) => e.toMap()).toList(),
  };
}
