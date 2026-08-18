import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/interaction_service.dart';
import '../services/notification_service.dart';
import 'owner_page.dart';
import 'admin_page.dart';
import 'reporter_page.dart';
import 'login_page.dart';
import 'profile_settings_page.dart';

const _red = Color(0xFFE60000);
const _darkRed = Color(0xFFC20000);
const _blue = Color(0xFF0D47A1);
const _bg = Color(0xFFF7F8FA);


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final service = NewsService();

  int nav = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: _body()),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    const labels = ['Read', 'Explore', 'Account'];
    const icons = [
      Icons.article_outlined,
      Icons.explore_outlined,
      Icons.person_outline_rounded,
    ];

    return NavigationBar(
      height: 76,
      backgroundColor: const Color(0xFFFFF0ED),
      indicatorColor: const Color(0xFFFFDCD7),
      selectedIndex: nav,
      onDestinationSelected: (v) => setState(() => nav = v),
      destinations: List.generate(
        labels.length,
        (i) => NavigationDestination(
          icon: Icon(icons[i], size: 25),
          selectedIcon: Icon(icons[i], size: 27),
          label: labels[i],
        ),
      ),
    );
  }

  Widget _body() {
    switch (nav) {
      case 1:
        return const ExplorePage();
      case 2:
        return const AccountPage();
      default:
        return _readPage();
    }
  }

  Widget _readPage() {
    return Column(
      children: [
        _header(),
        const SizedBox(height: 4),
        Expanded(
          child: StreamBuilder<List<NewsItem>>(
            stream: service.watchNews('అన్నీ'),
            builder: (_, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(child: Text('News error: ${s.error}'));
              }
              final items = s.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('No news available'));
              }

              final today = DateTime.now();
              final breaking = items.where((item) {
                final d = item.publishedAt?.toLocal();
                final isToday = d != null && d.year == today.year && d.month == today.month && d.day == today.day;
                return isToday && item.breaking;
              }).toList();

              final top = items.where((item) {
                final d = item.publishedAt?.toLocal();
                final isToday = d != null && d.year == today.year && d.month == today.month && d.day == today.day;
                return isToday;
              }).take(1).toList();

              final latest = items.where((item) => !top.contains(item)).toList();

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                children: [
                  BreakingTicker(items: breaking),
                  const SizedBox(height: 8),
                  _categoryStrip(context),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Top News', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 10),
                  ...top.map((item) => NewsCard(item: item)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Latest News', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 10),
                  ...latest.map((item) => NewsCard(item: item)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryStrip(BuildContext context) {
    const categories = [
      'ఆంధ్రప్రదేశ్', 'తెలంగాణ', 'దేశం', 'అంతర్జాతీయం', 'బిజినెస్', 'క్రీడలు', 'సినిమా', 'టెక్నాలజీ', 'విద్య', 'ఆరోగ్యం', 'రాశి ఫలాలు', 'దేవుళ్ళు', 'వాతావరణం', 'తెలుగు మేమ్స్',
    ];
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryNewsPage(category: categories[i]))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF12A5D7), borderRadius: BorderRadius.circular(12)),
            child: Text(categories[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${two(now.day)} ${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][now.month - 1]} ${now.year}';
    final time = '${two(now.hour % 12 == 0 ? 12 : now.hour % 12)}:${two(now.minute)}:${two(now.second)} ${now.hour >= 12 ? "PM" : "AM"}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Row(children: [
            Container(width: 58, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(14)), child: const Text('SRI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            const Text('NEWS', style: TextStyle(color: _red, fontSize: 29, fontWeight: FontWeight.w900)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('▣  $date', style: const TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.w800)),
            const Text('|', style: TextStyle(color: Colors.black26)),
            const Text('● LIVE', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w900)),
            const Text('|', style: TextStyle(color: Colors.black26)),
            Text('◷ $time', style: const TextStyle(color: _red, fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ),
      ],
    );
  }
}



class NewsCard extends StatefulWidget {
  final NewsItem item;
  final bool featured;
  final bool fullMatter;

  const NewsCard({
    super.key,
    required this.item,
    this.featured = false,
    this.fullMatter = false,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  final GlobalKey _postKey = GlobalKey();
  final PageController _imageController = PageController();
  int _imageIndex = 0;

  NewsItem get item => widget.item;
  bool get featured => widget.featured;
  bool get fullMatter => widget.fullMatter;

  @override
  void didUpdateWidget(covariant NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _imageIndex = 0;
      if (_imageController.hasClients) {
        _imageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  String _postDateLabel() {
    final publishedAt = item.publishedAt;
    if (publishedAt == null) return '';

    final date = publishedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final postDay = DateTime(date.year, date.month, date.day);
    final days = today.difference(postDay).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }


  List<String> _postImageUrls() {
    final urls = item.imageUrls
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toList();

    if (urls.isNotEmpty) return urls;

    final single = item.imageUrl.trim();
    return single.isNotEmpty ? <String>[single] : <String>[];
  }

  Uint8List? _dataImageBytes(String value) {
    if (!value.startsWith('data:image/')) return null;
    try {
      final comma = value.indexOf(',');
      if (comma <= 0) return null;
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }


  Future<void> _openImageViewer(
    BuildContext context,
    List<String> urls, {
    int initialIndex = 0,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          urls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _loginRequired(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _comment(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _loginRequired(context);
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) {
        return;
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CommentSheet(item: item),
    );
  }

  Future<void> _like(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _loginRequired(context);
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) {
        return;
      }
    }

    try {
      await InteractionService().toggleLike(item.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Like failed: $e')),
        );
      }
    }
  }

  Widget _newsImage() {
    final urls = _postImageUrls();

    if (urls.isEmpty) return _fallbackImage();

    Widget imageFor(String value) {
      final bytes = _dataImageBytes(value);
      if (bytes == null || bytes.isEmpty) return _fallbackImage();

      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }

    Widget tappableImage(String value, {int index = 0}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openImageViewer(context, urls, initialIndex: index),
        child: imageFor(value),
      );
    }

    final imageHeight = fullMatter ? 420.0 : 104.0;

    if (urls.length == 1) {
      return SizedBox(
        width: double.infinity,
        height: imageHeight,
        child: tappableImage(urls.first),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: imageHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _imageController,
            itemCount: urls.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              if (mounted) setState(() => _imageIndex = index);
            },
            itemBuilder: (_, index) => tappableImage(
              urls[index],
              index: index,
            ),
          ),
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  urls.length,
                  (index) => Container(
                    width: index == _imageIndex ? 9 : 7,
                    height: index == _imageIndex ? 9 : 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _imageIndex
                          ? Colors.white
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openImageViewer(
                  context,
                  urls,
                  initialIndex: _imageIndex,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      height: featured ? 220 : 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1976D2),
            Color(0xFF001B44),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 18,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'BREAKING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'బ్రేకింగ్',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'న్యూస్',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!fullMatter) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsDetailPage(item: item))),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, height: 104, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _newsImage())),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (item.title.isNotEmpty) Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, height: 1.2, fontWeight: FontWeight.w900, color: Color(item.titleColor))),
                const SizedBox(height: 5),
                if ((item.description.isNotEmpty || item.content.isNotEmpty)) Text(item.description.isNotEmpty ? item.description : item.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.35, color: Color(item.matterColor))),
                const SizedBox(height: 5),
                Text(_postDateLabel(), style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w700)),
              ])),
            ]),
          ),
        ),
      );
    }

    final interactions = InteractionService();
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 18),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _newsImage(),
        Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 8), child: Text(item.title, style: TextStyle(fontSize: 27, height: 1.25, fontWeight: FontWeight.w900, color: Color(item.titleColor)))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 16), child: Text(item.description.isNotEmpty ? item.description : item.content, style: TextStyle(fontSize: 18, height: 1.65, color: Color(item.matterColor), fontWeight: FontWeight.w500))),
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 7), child: Row(children: [
          StreamBuilder<bool>(stream: interactions.likedByMe(item.id), builder: (_, liked) => IconButton(onPressed: () => _like(context), icon: Icon(liked.data == true ? Icons.favorite : Icons.favorite_border_rounded, color: liked.data == true ? _red : const Color(0xFF493D3D)))),
          StreamBuilder<int>(stream: interactions.likeCount(item.id), builder: (_, count) => Text('${count.data ?? 0}')),
          const SizedBox(width: 8),
          IconButton(onPressed: () => _comment(context), icon: const Icon(Icons.mode_comment_outlined, color: Color(0xFF493D3D))),
          StreamBuilder<int>(stream: interactions.commentCount(item.id), builder: (_, count) => Text('${count.data ?? 0}')),
        ])),
      ]),
    );
  }

}

class NewsDetailPage extends StatelessWidget {
  final NewsItem item;
  const NewsDetailPage({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('SRI NEWS', style: TextStyle(color: _red, fontWeight: FontWeight.w900)),
        backgroundColor: _bg, foregroundColor: Colors.black87, elevation: 0,
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 30), child: NewsCard(item: item, fullMatter: true)),
    );
  }
}

class CategoryNewsPage extends StatelessWidget {
  final String category;
  const CategoryNewsPage({super.key, required this.category});
  @override
  Widget build(BuildContext context) {
    final service = NewsService();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: Text(category), backgroundColor: _bg, foregroundColor: Colors.black87, elevation: 0),
      body: StreamBuilder<List<NewsItem>>(
        stream: service.watchNews(category),
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('News error: ${s.error}'));
          final items = s.data ?? [];
          return ListView.builder(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), itemCount: items.length, itemBuilder: (_, i) => NewsCard(item: items[i]));
        },
      ),
    );
  }
}

class BreakingTicker extends StatefulWidget {
  final List<NewsItem> items;
  const BreakingTicker({super.key, required this.items});
  @override
  State<BreakingTicker> createState() => _BreakingTickerState();
}

class _BreakingTickerState extends State<BreakingTicker> {
  final controller = ScrollController();
  Timer? timer;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _start()); }
  @override
  void didUpdateWidget(covariant BreakingTicker oldWidget) { super.didUpdateWidget(oldWidget); WidgetsBinding.instance.addPostFrameCallback((_) => _start()); }
  void _start() {
    timer?.cancel();
    if (!mounted || widget.items.isEmpty) return;
    timer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!controller.hasClients || controller.position.maxScrollExtent <= 0) return;
      final next = controller.offset + 1.2;
      controller.jumpTo(next >= controller.position.maxScrollExtent ? 0 : next);
    });
  }
  @override
  void dispose() { timer?.cancel(); controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final text = widget.items.map((e) => e.title == 'BREAKING NEWS' ? (e.description.isNotEmpty ? e.description : e.content) : e.title).where((e) => e.trim().isNotEmpty).join('   •   ');
    return Container(
      height: 48, margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _red.withOpacity(.35)), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)), child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), color: _blue, child: const Text('BREAKING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), color: _red, child: const Text('NEWS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
        ])),
        const SizedBox(width: 8),
        Expanded(child: ClipRect(child: SingleChildScrollView(controller: controller, scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), child: Align(alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _red))))),
      ]),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullScreenImageViewer({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1).toInt();
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Uint8List? _bytes(String value) {
    if (!value.startsWith('data:image/')) return null;
    try {
      final comma = value.indexOf(',');
      if (comma <= 0) return null;
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.urls.length == 1
              ? 'Image'
              : '${_index + 1} / ${widget.urls.length}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _index = index),
        itemCount: widget.urls.length,
        itemBuilder: (_, index) {
          final bytes = _bytes(widget.urls[index]);

          if (bytes == null || bytes.isEmpty) {
            return const Center(
              child: Text(
                'Image unavailable',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              panEnabled: true,
              scaleEnabled: true,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Image unavailable',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CommentSheet extends StatefulWidget {
  final NewsItem item;
  const CommentSheet({super.key, required this.item});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final controller = TextEditingController();
  final service = InteractionService();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await service.addComment(widget.item.id, text);
      controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment post చేయలేకపోయాం.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 45, height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('Comments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                    StreamBuilder<int>(
                      stream: service.commentCount(widget.item.id),
                      builder: (_, s) => Text('${s.data ?? 0}'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: service.comments(widget.item.id),
                  builder: (_, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('ఇంకా comments లేవు. మొదటి comment మీరే చేయండి.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data();
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: _red,
                            child: Text(((data['userName'] ?? 'S').toString().trim().isEmpty ? 'S' : (data['userName'] ?? 'S').toString().trim().substring(0, 1)).toUpperCase(),
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(data['userName'] ?? 'SRI News User', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(data['text'] ?? ''),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 4,
                        minLines: 1,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: 'మీ comment రాయండి...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: sending ? null : send,
                      icon: sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
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
}


class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        children: [
          Icon(icon, color: _red, size: 30),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WatchPage extends StatelessWidget {
  const WatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NewsService();
    return Column(
      children: [
        _SectionHeader(
          title: 'Watch',
          subtitle: 'తాజా వార్తలు',
          icon: Icons.play_circle_outline,
        ),
        Expanded(
          child: StreamBuilder<List<NewsItem>>(
            stream: service.watchNews('అన్నీ'),
            builder: (_, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(child: Text('News error: ${s.error}'));
              }
              final items = s.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('వార్తలు అందుబాటులో లేవు'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: items.length,
                itemBuilder: (_, i) => NewsCard(
                  item: items[i],
                  featured: i == 0,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final service = NewsService();
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: TextField(
            controller: controller,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'వార్తలు వెతకండి',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NewsItem>>(
            stream: service.watchNews('అన్నీ'),
            builder: (_, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(child: Text('News error: ${s.error}'));
              }

              final all = s.data ?? [];
              final items = query.isEmpty
                  ? all
                  : all.where((item) {
                      final haystack =
                          '${item.title} ${item.description} ${item.content} ${item.category}'
                              .toLowerCase();
                      return haystack.contains(query);
                    }).toList();

              if (items.isEmpty) {
                return const Center(child: Text('వార్తలు కనబడలేదు'));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: items.length,
                itemBuilder: (_, i) => NewsCard(
                  item: items[i],
                  featured: false,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NewsService();
    const categories = [
      ('ఆంధ్రప్రదేశ్', Icons.map_outlined),
      ('తెలంగాణ', Icons.location_on_outlined),
      ('దేశం', Icons.account_balance_outlined),
      ('అంతర్జాతీయం', Icons.public_outlined),
      ('బిజినెస్', Icons.business_center_outlined),
      ('క్రీడలు', Icons.sports_cricket_outlined),
      ('సినిమా', Icons.movie_outlined),
      ('టెక్నాలజీ', Icons.devices_outlined),
      ('విద్య', Icons.school_outlined),
      ('ఆరోగ్యం', Icons.health_and_safety_outlined),
      ('రాశి ఫలాలు', Icons.auto_awesome_outlined),
      ('దేవుళ్ళు', Icons.temple_hindu_outlined),
      ('వాతావరణం', Icons.wb_sunny_outlined),
      ('తెలుగు మేమ్స్', Icons.mood_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
      children: [
        const Text(
          'అన్వేషించండి',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'మీకు కావాల్సిన వార్తల వర్గాన్ని ఎంచుకోండి',
          style: TextStyle(color: Colors.black54, fontSize: 15),
        ),
        const SizedBox(height: 20),
        const Text(
          'వార్తల వర్గాలు',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.42,
          ),
          itemBuilder: (_, i) {
            final category = categories[i].$1;
            final icon = categories[i].$2;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: _bg,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  builder: (_) => _CategoryNewsSheet(
                    service: service,
                    category: category,
                  ),
                );
              },
              child: Card(
                color: Colors.white,
                elevation: 1,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? const Color(0xFFEAF2FF)
                              : const Color(0xFFFFECE9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: i.isEven ? _blue : _red,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        category,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AllNewsPage extends StatelessWidget {
  const _AllNewsPage();

  @override
  Widget build(BuildContext context) {
    final service = NewsService();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('అన్ని వార్తలు'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<List<NewsItem>>(
        stream: service.watchNews('అన్నీ'),
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(child: Text('News error: ${s.error}'));
          }
          final items = s.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('వార్తలు అందుబాటులో లేవు'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            itemCount: items.length,
            itemBuilder: (_, i) => NewsCard(
              item: items[i],
              featured: i == 0,
              fullMatter: true,
            ),
          );
        },
      ),
    );
  }
}

class _CategoryNewsSheet extends StatelessWidget {
  final NewsService service;
  final String category;

  const _CategoryNewsSheet({
    required this.service,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<NewsItem>>(
                stream: service.watchNews(category),
                builder: (_, s) {
                  if (s.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return Center(child: Text('News error: ${s.error}'));
                  }
                  final items = s.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('ఈ వర్గంలో వార్తలు లేవు'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) => NewsCard(item: items[i], fullMatter: true),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatefulWidget {
  final String userId;
  const _ProfileAvatar({required this.userId});

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  File? file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await getApplicationDocumentsDirectory();
    final candidate = File('${dir.path}/sri_news_profile_${widget.userId}.jpg');
    if (await candidate.exists() && mounted) {
      setState(() => file = candidate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: _red,
      backgroundImage: file != null ? FileImage(file!) : null,
      child: file == null
          ? const Icon(Icons.person, color: Colors.white, size: 30)
          : null,
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Widget _accountAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _red, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black45),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _editAccountName(
    BuildContext context,
    User user,
    String currentName,
  ) async {
    final controller = TextEditingController(
      text: currentName == 'SRI News User' ? '' : currentName,
    );

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty) return;

    try {
      final name = value.trim();

      await user.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'name': name,
          'displayName': name,
        },
        SetOptions(merge: true),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name update failed: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
            children: [
              const Text(
                'Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              _accountAction(
                icon: Icons.login_outlined,
                title: 'Login',
                subtitle: 'Owner, Admin, Reporter or User',
                onTap: () => _openLogin(context),
              ),
              const SizedBox(height: 10),
              _accountAction(
                icon: Icons.assignment_outlined,
                title: 'Admin / Reporter Apply',
                subtitle: 'Apply here. Owner approval is required.',
                onTap: () => _openLogin(context),
              ),
            ],
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (_, userSnapshot) {
            final data = userSnapshot.data?.data() ?? {};
            final name = (data['name'] ??
                    data['displayName'] ??
                    user.displayName ??
                    'SRI News User')
                .toString()
                .trim();
            final role = (data['role'] ?? 'user').toString().trim().toLowerCase();
            final reporterStatus =
                (data['reporterStatus'] ?? '').toString().trim().toLowerCase();
            final adminStatus =
                (data['adminStatus'] ?? '').toString().trim().toLowerCase();

            final isOwner = role == 'owner';
            final isAdmin = role == 'admin' || role == 'administrator';
            final isReporter = role == 'reporter' || reporterStatus == 'approved';

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
              children: [
                const Text(
                  'Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: _ProfileAvatar(userId: user.uid),
                    title: Text(
                      name.isEmpty ? 'SRI News User' : name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      role == 'administrator'
                          ? 'ADMIN'
                          : role.toUpperCase(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _accountAction(
                  icon: Icons.edit_outlined,
                  title: 'Edit Name',
                  subtitle: 'Change your account name',
                  onTap: () => _editAccountName(
                    context,
                    user,
                    name.isEmpty ? 'SRI News User' : name,
                  ),
                ),
                const SizedBox(height: 12),
                if (isOwner)
                  _accountAction(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Owner Dashboard',
                    subtitle: 'Users, Admins, Reporters and full controls',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OwnerPage()),
                    ),
                  )
                else if (isAdmin)
                  _accountAction(
                    icon: Icons.verified_user_outlined,
                    title: 'Admin Dashboard',
                    subtitle: 'Approve or reject reporter posts',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminPage()),
                    ),
                  )
                else if (isReporter)
                  _accountAction(
                    icon: Icons.edit_note_outlined,
                    title: 'Reporter Center',
                    subtitle: 'Create posts and check approval status',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ReporterPage()),
                    ),
                  ),
                if (isOwner || isAdmin || isReporter)
                  const SizedBox(height: 10),
                if (reporterStatus == 'pending')
                  _accountAction(
                    icon: Icons.hourglass_top_outlined,
                    title: 'Reporter Application',
                    subtitle: 'Waiting for Owner approval',
                    onTap: () => _openLogin(context),
                  ),
                if (adminStatus == 'pending')
                  _accountAction(
                    icon: Icons.hourglass_top_outlined,
                    title: 'Admin Application',
                    subtitle: 'Waiting for Owner approval',
                    onTap: () => _openLogin(context),
                  ),
                if (reporterStatus == 'pending' || adminStatus == 'pending')
                  const SizedBox(height: 10),
                _accountAction(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Login / Apply',
                  subtitle: 'Change role selection or submit an application',
                  onTap: () => _openLogin(context),
                ),
                const SizedBox(height: 10),
                _accountAction(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Profile Settings',
                  subtitle: 'Change your profile picture',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileSettingsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _accountAction(
                  icon: Icons.menu_book_outlined,
                  title: 'నిబంధనలు & షరతులు',
                  subtitle: 'SRI NEWS నిబంధనలు మరియు షరతులు',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsConditionsPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: () => FirebaseAuth.instance.signOut(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  static const String _content = """SRI NEWS — నిబంధనలు & షరతులు

SRI NEWS అనేది వార్తలను చదవడానికి మరియు వార్తల నిర్వహణకు రూపొందించిన Flutter + Firebase ఆధారిత వార్తా అప్లికేషన్.

1. వినియోగదారు

సాధారణ వినియోగదారు ఖాతాను సృష్టించి లాగిన్ అవ్వవచ్చు. ప్రచురించిన వార్తలను చదవవచ్చు, విభాగాల ద్వారా వార్తలను చూడవచ్చు, వార్తలకు లైక్ చేయవచ్చు, వ్యాఖ్యలు చేయవచ్చు మరియు ఫోన్‌లోని షేర్ సదుపాయం ద్వారా వార్తలను పంచుకోవచ్చు.

సాధారణ వినియోగదారులకు Owner/Admin నిర్వహణ సదుపాయాలకు అనుమతి ఉండదు.

2. రిపోర్టర్

రిపోర్టర్‌గా మారడానికి ముందుగా దరఖాస్తు చేయాలి. Owner లేదా Admin ఆ దరఖాస్తును పరిశీలించి ఆమోదించవచ్చు లేదా తిరస్కరించవచ్చు.

ఆమోదించబడిన రిపోర్టర్‌కే రిపోర్టర్ యాక్సెస్ లభిస్తుంది. ఆమోదం తర్వాత రిపోర్టర్ వార్తలను సృష్టించి సమర్పించవచ్చు. సమర్పించిన వార్తలు ప్రచురణకు ముందు Owner/Admin పరిశీలన మరియు ఆమోద ప్రక్రియ ద్వారా వెళ్తాయి.

అవసరమైనప్పుడు Owner/Admin రిపోర్టర్ యాక్సెస్‌ను తొలగించవచ్చు.

3. అడ్మిన్

అడ్మిన్‌కు అప్లికేషన్‌లో అనుమతించబడిన నిర్వహణ సదుపాయాలు ఉంటాయి. ఇందులో వినియోగదారులు, రిపోర్టర్ దరఖాస్తులు, రిపోర్టర్ ఆమోదాలు/తిరస్కరణలు, సమర్పించిన వార్తలు మరియు వార్తల ఆమోదం వంటి పనులు ఉండవచ్చు.

4. ఓనర్

Owner‌కు అప్లికేషన్ నిర్వహణలో అత్యున్నత స్థాయి అధికారం ఉంటుంది. Owner వినియోగదారులు, Adminలు, Reporters, Reporter applications, Reporter access, సమర్పించిన వార్తలు మరియు వార్తల ఆమోద ప్రక్రియను నిర్వహించవచ్చు.

5. వార్తల ప్రక్రియ

రిపోర్టర్ దరఖాస్తు
→ Owner/Admin పరిశీలన
→ రిపోర్టర్ ఆమోదం
→ రిపోర్టర్ యాక్సెస్
→ వార్త సమర్పణ
→ Owner/Admin పరిశీలన
→ వార్త ఆమోదం
→ ప్రచురించిన వార్త
→ వినియోగదారులు చదవడం మరియు పరస్పరం వ్యవహరించడం

6. వార్తలతో వినియోగదారు పరస్పర చర్య

వినియోగదారులు ప్రచురించిన వార్తలను చదవవచ్చు. లైక్/లైక్ తొలగింపు, వ్యాఖ్యలు మరియు షేర్ వంటి సదుపాయాలు అందుబాటులో ఉంటాయి. వ్యాఖ్యలు చేయడానికి లాగిన్ అవసరం.

7. వార్తల పరిశీలన

రిపోర్టర్ సమర్పించిన వార్త ముందుగా పెండింగ్‌లో ఉండవచ్చు. Owner/Admin దాన్ని పరిశీలించి ఆమోదించవచ్చు లేదా తిరస్కరించవచ్చు. ఆమోదించిన కంటెంట్ మాత్రమే ప్రచురణకు వెళ్లేలా నియంత్రిత ప్రక్రియ ఉంటుంది.

8. ఖాతాలు మరియు పేర్లు

వినియోగదారులు, Reporters, Admins మరియు Owner ఖాతాలకు Account సదుపాయం ద్వారా తమ పేరు మార్చుకునే అవకాశం ఉంటుంది. పేరు మార్చినప్పుడు ఖాతా ప్రొఫైల్ సమాచారం కూడా నవీకరించబడుతుంది.

9. Firebase Authentication

SRI NEWS వినియోగదారు నమోదు మరియు లాగిన్ కోసం Firebase Authenticationను ఉపయోగిస్తుంది. రక్షిత నిర్వహణ సదుపాయాలకు అవసరమైన Authentication మరియు పాత్ర ఆధారిత అనుమతులు అమలులో ఉండాలి.

10. Cloud Firestore

వినియోగదారు ప్రొఫైల్ సమాచారం, పాత్రలు, Reporter applications, వార్తలు, లైకులు, వ్యాఖ్యలు మరియు ఇతర అప్లికేషన్ డేటా Cloud Firestoreలో నిర్వహించబడవచ్చు.

11. భద్రత

సాధారణ వినియోగదారులు రక్షిత నిర్వహణ సదుపాయాలను ఉపయోగించకూడదు. Reporter access ఆమోదంపై ఆధారపడి ఉంటుంది. Reporter వార్తల సమర్పణ మరియు Owner/Admin నిర్వహణ చర్యలు Firestore Security Rules ద్వారా నియంత్రించబడాలి.

12. నిర్వహణ మరియు ప్రచురణ

Owner/Admin అనుమతి లేకుండా సాధారణ వినియోగదారు నేరుగా నిర్వహణ కార్యకలాపాలు లేదా నియంత్రిత ప్రచురణ చర్యలు చేయకూడదు.

13. Firebase సెటప్

అప్లికేషన్ సరిగ్గా పనిచేయడానికి Firebase Authentication, Email/Password sign-in, Cloud Firestore మరియు ప్రాజెక్ట్‌కు సంబంధించిన Firestore Security Rules సరైన విధంగా కాన్ఫిగర్ చేసి డిప్లాయ్ చేయాలి.

14. ముఖ్యమైన సమాచారం

అప్లికేషన్‌లో కనిపించే ఖచ్చితమైన స్క్రీన్లు, విభాగాలు, ఫీచర్లు మరియు అనుమతులు ప్రస్తుత Flutter source code మరియు Firebase configurationపై ఆధారపడి ఉంటాయి.

ఈ నిబంధనలు & షరతులు SRI NEWS అప్లికేషన్ యొక్క వినియోగదారు, రిపోర్టర్, Admin మరియు Owner కార్యకలాపాలు, వార్తల సమర్పణ/ఆమోద ప్రక్రియ మరియు Firebase ఆధారిత భద్రతా విధానాన్ని వివరిస్తాయి.""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('నిబంధనలు & షరతులు'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: SelectableText(
            _content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

