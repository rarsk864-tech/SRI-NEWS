import 'reporter_page.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/interaction_service.dart';
import '../services/notification_service.dart';
import 'owner_page.dart';
import 'admin_page.dart';
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
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<NewsItem>>(
            stream: service.watchNews('అన్నీ'),
            builder: (_, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (s.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'News error: ${s.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final items = s.data ?? [];

              if (items.isEmpty) {
                return const Center(child: Text('No news available'));
              }

              // One news item at a time. The item is NOT height-limited:
              // if the news has more content, the user can keep scrolling
              // through the complete matter. The next news starts only after
              // the current news finishes.
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
                itemCount: items.length,
                itemBuilder: (_, i) => NewsCard(
                  item: items[i],
                  featured: true,
                  fullMatter: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'SRI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'NEWS',
            style: TextStyle(
              color: _red,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const Spacer(),
          IconButton(
            splashRadius: 23,
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 31,
              color: Color(0xFF4B3B3B),
            ),
          ),
        ],
      ),
    );
  }

}


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    NotificationService.addListener(_refresh);
  }

  @override
  void dispose() {
    NotificationService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.notifications;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171313),
        elevation: 0,
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final notification = notifications[index];
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: _red,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(notification.body),
                    ),
                  ),
                );
              },
            ),
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

  Future<void> _share(BuildContext context) async {
    final text = 'SRI NEWS\n\n${item.title}\n\n${item.description}';
    await Share.share(text, subject: 'SRI NEWS - ${item.title}');
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

  Future<void> _downloadFullPost(BuildContext context) async {
    try {
      final urls = _postImageUrls();

      // Image-only post: download/share every image separately.
      // A post with title/matter: download the complete visible post as
      // one PNG so the image + title + matter stay together.
      final hasMatter = item.title.trim().isNotEmpty ||
          item.description.trim().isNotEmpty ||
          item.content.trim().isNotEmpty;

      if (!hasMatter) {
        if (urls.isEmpty) throw Exception('No images available');

        final files = <XFile>[];

        for (var i = 0; i < urls.length; i++) {
          final bytes = _dataImageBytes(urls[i]);
          if (bytes == null || bytes.isEmpty) continue;

          files.add(
            XFile.fromData(
              bytes,
              name: 'sri_news_${item.id}_${i + 1}.jpg',
              mimeType: 'image/jpeg',
            ),
          );
        }

        if (files.isEmpty) throw Exception('Could not read post images');

        await Share.shareXFiles(
          files,
          text: 'SRI NEWS - Images',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                files.length == 1
                    ? 'Image ready to save'
                    : '${files.length} images ready to save',
              ),
            ),
          );
        }
        return;
      }

      // Text/news post: capture the complete NewsCard as one image.
      final renderObject = _postKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('Post is not ready for download');
      }

      await WidgetsBinding.instance.endOfFrame;

      final pixelRatio =
          (MediaQuery.devicePixelRatioOf(context) * 2.0).clamp(2.0, 4.0);

      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        throw Exception('Could not create post image');
      }

      final pngBytes = byteData.buffer.asUint8List();

      await Share.shareXFiles(
        [
          XFile.fromData(
            pngBytes,
            name: 'sri_news_post_${item.id}.png',
            mimeType: 'image/png',
          ),
        ],
        text: 'SRI NEWS - ${item.title}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full post ready to save')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
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

    final imageHeight = featured ? 420.0 : 300.0;

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
    final interactions = InteractionService();

    return RepaintBoundary(
      key: _postKey,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Share action is shown on the right side of the news visual.
                Stack(
                  children: [
                    _newsImage(),
                    if (_postDateLabel().isNotEmpty)
                      Positioned(
                        left: 14,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.62),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _postDateLabel(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                if (item.title.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      item.title,
                      maxLines: fullMatter ? null : (featured ? 3 : 2),
                      overflow: fullMatter ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: featured ? 25 : 23,
                        height: 1.28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF171313),
                      ),
                    ),
                  ),

                if ((item.description.isNotEmpty || item.content.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),
                    child: Text(
                      item.description.isNotEmpty ? item.description : item.content,
                      maxLines: fullMatter ? null : 4,
                      overflow: fullMatter ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: featured ? 17 : 16,
                        height: 1.5,
                        color: const Color(0xFF6C6767),
                      ),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
            child: Row(
              children: [
                StreamBuilder<bool>(
                  stream: interactions.likedByMe(item.id),
                  builder: (_, liked) => IconButton(
                    tooltip: 'Like',
                    onPressed: () => _like(context),
                    icon: Icon(
                      liked.data == true
                          ? Icons.favorite
                          : Icons.favorite_border_rounded,
                      color: liked.data == true
                          ? _red
                          : const Color(0xFF493D3D),
                      size: 29,
                    ),
                  ),
                ),
                StreamBuilder<int>(
                  stream: interactions.likeCount(item.id),
                  builder: (_, count) => Text(
                    '${count.data ?? 0}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Comment',
                  onPressed: () => _comment(context),
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    size: 28,
                    color: Color(0xFF493D3D),
                  ),
                ),
                StreamBuilder<int>(
                  stream: interactions.commentCount(item.id),
                  builder: (_, count) => Text(
                    '${count.data ?? 0}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Download',
                  onPressed: () => _downloadFullPost(context),
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 29,
                    color: Color(0xFF493D3D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
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
      ('తెలంగాణ', Icons.location_on_outlined),
      ('ఆంధ్రప్రదేశ్', Icons.map_outlined),
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

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
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
              const SizedBox(height: 18),
              _accountAction(
                icon: Icons.description_outlined,
                title: 'నిబంధనలు & షరతులు',
                subtitle: 'SRI NEWS Terms and Conditions',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsPage()),
                ),
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
                      MaterialPageRoute(builder: (_) => const ReporterPage()),
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

  Widget _accountAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: _red),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}



class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const String _readme = '''# SRI NEWS

SRI NEWS is a Flutter + Firebase news application designed to provide a complete news-reading and news-management platform.

## What is SRI NEWS?

SRI NEWS allows normal users to read and interact with news while authorized reporters can submit news for publication. Admins and the Owner manage users, reporters, news, approvals, and other administrative functions.

The application is divided into two main areas:

- **User side** — for reading and interacting with published news.
- **Management side** — for Owner, Admin, and Reporter operations.

---

# Users and Roles

SRI NEWS has four main roles:

## 1. User

A normal registered user can:

- Create an account and log in.
- Browse published news.
- Read complete news articles.
- Explore news by category.
- Like and unlike news.
- Comment on news.
- Share news using the device share sheet.
- Manage their normal user account through the available app features.

Users do not have access to Owner/Admin management functions.

## 2. Reporter

A Reporter is a user who is authorized to submit news.

Reporter workflow:

1. A person applies/request access to become a Reporter.
2. The Owner or Admin reviews the Reporter application.
3. The application can be approved or rejected.
4. Only an approved Reporter receives Reporter access.
5. An approved Reporter can create and submit news.
6. Submitted news can go through the required Owner/Admin review and approval process before publication.

Reporter access can be removed by the Owner/Admin when required.

## 3. Admin

The Admin manages the application from the management side.

Admin responsibilities can include:

- Managing users.
- Managing Reporter applications.
- Approving or rejecting Reporters.
- Removing Reporter access when required.
- Reviewing submitted news.
- Approving news for publication.
- Managing available app content and administrative data.
- Using the available administrative editing/management controls.

Admin does not operate as a normal news reader when using the protected management area; the Admin has management privileges according to the configured Firebase permissions.

## 4. Owner

The Owner has the highest level of application management.

Owner responsibilities can include:

- Managing users.
- Managing Admins.
- Managing Reporters.
- Approving or rejecting Reporter applications.
- Removing Reporter access.
- Reviewing, editing, approving, or managing submitted news.
- Managing application-level administration.
- Monitoring the overall user/role structure.
- Performing Owner-level management operations.

The exact actions available to Admin and Owner are controlled by the application's authentication and Firestore security configuration.

---

# How SRI NEWS Works

The basic news lifecycle is:

**Reporter Application**
→ **Owner/Admin Review**
→ **Reporter Approval**
→ **Reporter Access**
→ **News Submission**
→ **Owner/Admin Review**
→ **News Approval**
→ **Published News**
→ **Users Read and Interact**

This keeps submitted content under management review before it becomes published news.

---

# User News Experience

The normal user flow is:

**Open SRI NEWS**
→ **Home**
→ **Browse News**
→ **Explore Categories**
→ **Open News**
→ **Read Article**
→ **Like / Comment / Share**

## News interactions

- Share news from cards and article details using the device share sheet.
- Like/unlike news with a per-user Firestore record and live counts.
- Commenting requires a logged-in user.
- New users can create an account from the comment login prompt.
- Comments are stored under each news item and update live.

These existing interactions are part of the SRI NEWS user experience.

---

# News Categories and Content

SRI NEWS can organize news into categories so users can discover different types of content.

The application can contain categories such as:

- Latest News
- National
- International
- State
- Politics
- Crime
- Business
- Sports
- Cinema / Entertainment
- Technology
- Health
- Education
- Lifestyle
- Astrology / Rashi Phalalu
- Other categories configured by the application

The exact categories shown in the running application depend on the category data configured for the project.

---

# News Posting and Approval

## Reporter

An approved Reporter can submit a news item with the information supported by the application, such as:

- News title
- News description/content
- Category
- Image/media
- Other available news fields

After submission, the news can remain pending until an authorized Admin or Owner reviews it.

## Admin / Owner

The management side can review submitted news and decide whether it should be approved for publication.

Possible workflow:

- **Pending** — submitted and waiting for review.
- **Approved** — accepted for publication.
- **Rejected** — not accepted for publication.
- **Published** — approved news visible to normal users.

---

# User Accounts

Users can create accounts through Firebase Authentication.

A logged-in user can use authenticated features such as commenting.

The application uses role information to determine whether an account is:

- User
- Reporter
- Admin
- Owner

Privileged functions should only be available to accounts that have the required role/permissions.

---

# Firebase

SRI NEWS uses Firebase as its backend.

## Firebase Authentication

Authentication is used for:

- User registration.
- User login.
- Protected account access.
- Reporter/Admin/Owner authentication and authorization.

Enable Email/Password sign-in in Firebase Authentication before using user login/comments.

## Cloud Firestore

Firestore stores application data such as:

- User accounts/profile information.
- Roles and permissions-related data.
- Reporter applications.
- News/posts.
- News categories.
- Likes.
- Comments.
- Other application management data.

Like/unlike data is stored per user in Firestore and live counts are displayed.

Comments are stored under each news item and update live.

## Firestore Security Rules

Firestore Security Rules control which users can read or write different types of data.

The rules should protect:

- User data.
- Reporter access.
- Admin operations.
- Owner operations.
- News submission.
- News approval.
- Likes.
- Comments.

Deploy `firestore.rules` after enabling Firestore.

---

# Role and Permission Model

A simplified permission model is:

| Role | Read Published News | Like / Share | Comment | Submit News | Approve Reporter | Manage Users | Manage Admins |
|---|---|---|---|---|---|---|---|
| User | Yes | Yes | Yes, when logged in | No | No | No | No |
| Reporter | Yes | Yes | Yes, when logged in | Yes, after approval | No | No | No |
| Admin | Yes | Yes | Yes | Management access as configured | Yes | Yes | According to rules |
| Owner | Yes | Yes | Yes | Management access | Yes | Yes | Yes |

The final permissions are determined by the application's Firebase Authentication and Firestore Rules configuration.

---

# Protected Owner/Admin Login

The Owner/Admin login is intentionally not shown anywhere in the normal user UI.

To open the protected Admin route, tap the red **SRI** logo in the Home header **7 times within 2 seconds**.

Firebase ID token claim `admin == true` is required for the protected route, and non-owner/non-authorized accounts are rejected according to the application's configured authorization logic.

---

# Management Side

The management area is intended for authorized accounts.

## Owner Management

The Owner can manage the overall application and its users/roles, including:

- Users
- Admins
- Reporters
- Reporter approvals/rejections
- Reporter access removal
- Submitted news
- News approval
- Available management controls

## Admin Management

The Admin can manage the functions granted by the application's security rules, including:

- Users
- Reporters
- Reporter approvals/rejections
- Submitted news
- News approval
- Administrative content management

## Reporter Management

Reporter access follows an approval-based model. A Reporter should not be able to submit content as an authorized Reporter until the Reporter account has been approved.

---

# Content Safety and Review Flow

The management workflow is designed so that Reporter-submitted content can be reviewed before publication.

**Reporter submits**
→ **Pending**
→ **Admin/Owner reviews**
→ **Approve or Reject**
→ **Approved content becomes publishable**

This provides a controlled publishing workflow rather than allowing every normal user to publish directly.

---

# Application Structure

A typical SRI NEWS structure contains:

- Home page
- News cards
- News detail/article page
- Explore/categories
- User login/register
- Comment system
- Reporter area
- Admin area
- Owner area
- Firebase Authentication
- Cloud Firestore
- Firestore Security Rules

The exact screens and file structure depend on the current Flutter project implementation.

---

# Main App Flow

```text
                         SRI NEWS
                            |
              +-------------+-------------+
              |                           |
          USER SIDE                 MANAGEMENT SIDE
              |                           |
          Home / News              Owner / Admin / Reporter
              |                           |
      Explore / Categories        Role-based access
              |                           |
        News Details              Reporter approval
              |                           |
     Like / Comment / Share       News review
                                          |
                                    Publish / Reject
```

---

# Data Flow

```text
User
  |
  +--> Firebase Authentication
  |
  +--> Published News
  |       |
  |       +--> Like
  |       +--> Comment
  |       +--> Share
  |
Reporter
  |
  +--> Reporter Application
          |
          +--> Owner/Admin Approval
                    |
                    +--> Reporter Access
                              |
                              +--> News Submission
                                        |
                                        +--> Owner/Admin Review
                                                  |
                                                  +--> Published News

Owner/Admin
  |
  +--> Users
  +--> Reporters
  +--> News
  +--> Approvals
  +--> Management
```

---

# Security Principles

SRI NEWS should follow these principles:

1. Normal users must not access protected management functions.
2. Reporter access must depend on approval.
3. Reporter news submissions must be controlled by Firestore permissions.
4. Only authorized Admin/Owner accounts should approve or reject Reporter applications.
5. Only authorized management accounts should approve content for publication.
6. Firestore Security Rules should enforce permissions on the backend rather than relying only on UI restrictions.
7. Firebase Authentication should be enabled for protected user functionality.

---

# Firebase Setup

Before using the application:

1. Create/configure the Firebase project.
2. Add the Flutter application to Firebase.
3. Enable Firebase Authentication.
4. Enable Email/Password sign-in.
5. Enable Cloud Firestore.
6. Deploy the project's `firestore.rules`.
7. Configure the required role/authorization data.
8. Run the Flutter application.

---

# Project Goal

The goal of SRI NEWS is to provide a complete news platform where:

- Users can easily discover and read news.
- Users can interact with published news.
- Reporters can submit news after receiving authorization.
- Admins can manage the application and review content.
- The Owner has overall control of users, roles, reporters, and publishing.
- Firebase provides authentication, database storage, live updates, and backend security.

---

# Important

The exact features, categories, screens, permissions, and Firestore field names are determined by the current Flutter source code and Firebase configuration.

This README describes the intended SRI NEWS application structure and workflow. Any feature not implemented in the current source code still needs to be implemented in the corresponding Flutter/Firebase files.

''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'నిబంధనలు & షరతులు',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171313),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        child: Card(
          color: Colors.white,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
            child: SelectableText(
              _readme,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF444444),
              ),
            ),
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
