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
                subtitle: 'నిబంధనలు మరియు షరతులు',
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

SRI NEWS అనేది వార్తలను చదవడానికి మరియు వార్తల నిర్వహణకు రూపొందించిన Flutter + Firebase ఆధారిత వార్తా అప్లికేషన్.

## SRI NEWS అంటే ఏమిటి?

SRI NEWSలో సాధారణ వినియోగదారులు వార్తలను చదవవచ్చు మరియు వాటితో పరస్పరం వ్యవహరించవచ్చు. అనుమతి పొందిన రిపోర్టర్లు వార్తలను ప్రచురణ కోసం సమర్పించవచ్చు. అడ్మిన్ మరియు ఓనర్ వినియోగదారులు, రిపోర్టర్లు, వార్తలు, ఆమోదాలు మరియు ఇతర నిర్వహణ పనులను చూసుకుంటారు.

అప్లికేషన్ ప్రధానంగా రెండు భాగాలుగా ఉంటుంది:

- **వినియోగదారు విభాగం** — ప్రచురించిన వార్తలను చదవడానికి మరియు వాటితో పరస్పరం వ్యవహరించడానికి.
- **నిర్వహణ విభాగం** — ఓనర్, అడ్మిన్ మరియు రిపోర్టర్ కార్యకలాపాల కోసం.

---

# వినియోగదారులు మరియు పాత్రలు

SRI NEWSలో నాలుగు ప్రధాన పాత్రలు ఉన్నాయి:

## 1. వినియోగదారు

సాధారణంగా నమోదు చేసుకున్న వినియోగదారు:

- ఖాతాను సృష్టించి లాగిన్ అవ్వవచ్చు.
- ప్రచురించిన వార్తలను చూడవచ్చు.
- పూర్తి వార్తా కథనాలను చదవవచ్చు.
- విభాగాల ఆధారంగా వార్తలను అన్వేషించవచ్చు.
- వార్తలకు లైక్ చేయవచ్చు లేదా లైక్ తొలగించవచ్చు.
- వార్తలపై వ్యాఖ్యలు చేయవచ్చు.
- ఫోన్‌లోని షేర్ సదుపాయం ద్వారా వార్తలను పంచుకోవచ్చు.
- అప్లికేషన్‌లో అందుబాటులో ఉన్న సాధారణ ఖాతా సదుపాయాలను నిర్వహించవచ్చు.

సాధారణ వినియోగదారులకు ఓనర్/అడ్మిన్ నిర్వహణ సదుపాయాలు ఉండవు.

## 2. రిపోర్టర్

రిపోర్టర్ అనేది వార్తలను సమర్పించడానికి అనుమతి పొందిన వినియోగదారు.

రిపోర్టర్ ప్రక్రియ:

1. రిపోర్టర్‌గా మారడానికి దరఖాస్తు చేయాలి.
2. ఓనర్ లేదా అడ్మిన్ రిపోర్టర్ దరఖాస్తును పరిశీలిస్తారు.
3. దరఖాస్తును ఆమోదించవచ్చు లేదా తిరస్కరించవచ్చు.
4. ఆమోదించబడిన రిపోర్టర్‌కే రిపోర్టర్ సదుపాయం లభిస్తుంది.
5. ఆమోదించబడిన రిపోర్టర్ వార్తలను సృష్టించి సమర్పించవచ్చు.
6. సమర్పించిన వార్త ప్రచురణకు ముందు ఓనర్/అడ్మిన్ పరిశీలన మరియు ఆమోద ప్రక్రియ ద్వారా వెళ్తుంది.

అవసరమైనప్పుడు ఓనర్/అడ్మిన్ రిపోర్టర్ యాక్సెస్‌ను తొలగించవచ్చు.

## 3. అడ్మిన్

అడ్మిన్ నిర్వహణ విభాగం ద్వారా అప్లికేషన్‌ను నిర్వహిస్తారు.

అడ్మిన్ బాధ్యతల్లో ఇవి ఉండవచ్చు:

- వినియోగదారులను నిర్వహించడం.
- రిపోర్టర్ దరఖాస్తులను నిర్వహించడం.
- రిపోర్టర్లను ఆమోదించడం లేదా తిరస్కరించడం.
- అవసరమైనప్పుడు రిపోర్టర్ యాక్సెస్‌ను తొలగించడం.
- సమర్పించిన వార్తలను పరిశీలించడం.
- వార్తలను ప్రచురణకు ఆమోదించడం.
- అప్లికేషన్ కంటెంట్ మరియు నిర్వహణ సమాచారాన్ని నిర్వహించడం.
- అందుబాటులో ఉన్న నిర్వహణ సదుపాయాలను ఉపయోగించడం.

రక్షిత నిర్వహణ విభాగంలో అడ్మిన్, Firebaseలో అమలు చేసిన అనుమతుల ప్రకారం నిర్వహణ అధికారాలతో పనిచేస్తారు.

## 4. ఓనర్

అప్లికేషన్ నిర్వహణలో అత్యున్నత స్థాయి అధికారం ఓనర్‌కు ఉంటుంది.

ఓనర్ బాధ్యతల్లో ఇవి ఉండవచ్చు:

- వినియోగదారులను నిర్వహించడం.
- అడ్మిన్లను నిర్వహించడం.
- రిపోర్టర్లను నిర్వహించడం.
- రిపోర్టర్ దరఖాస్తులను ఆమోదించడం లేదా తిరస్కరించడం.
- రిపోర్టర్ యాక్సెస్‌ను తొలగించడం.
- సమర్పించిన వార్తలను పరిశీలించడం, సవరించడం, ఆమోదించడం లేదా నిర్వహించడం.
- అప్లికేషన్ స్థాయి నిర్వహణను చూసుకోవడం.
- వినియోగదారులు మరియు పాత్రల మొత్తం నిర్మాణాన్ని పర్యవేక్షించడం.
- ఓనర్ స్థాయి నిర్వహణ కార్యకలాపాలను నిర్వహించడం.

అడ్మిన్ మరియు ఓనర్‌కు అందుబాటులో ఉండే ఖచ్చితమైన చర్యలు అప్లికేషన్ Authentication మరియు Firestore భద్రతా నియమాల ద్వారా నియంత్రించబడతాయి.

---

# SRI NEWS ఎలా పనిచేస్తుంది

వార్తల ప్రాథమిక ప్రక్రియ:

**రిపోర్టర్ దరఖాస్తు**
→ **ఓనర్/అడ్మిన్ పరిశీలన**
→ **రిపోర్టర్ ఆమోదం**
→ **రిపోర్టర్ యాక్సెస్**
→ **వార్త సమర్పణ**
→ **ఓనర్/అడ్మిన్ పరిశీలన**
→ **వార్త ఆమోదం**
→ **ప్రచురించిన వార్త**
→ **వినియోగదారులు చదవడం మరియు పరస్పరం వ్యవహరించడం**

సమర్పించిన కంటెంట్ ప్రచురించబడే ముందు నిర్వహణ బృందం పరిశీలించగలదు.

---

# వినియోగదారుల వార్తా అనుభవం

సాధారణ వినియోగదారు ప్రక్రియ:

**SRI NEWS తెరవడం**
→ **హోమ్**
→ **వార్తలను చూడడం**
→ **విభాగాలను అన్వేషించడం**
→ **వార్తను తెరవడం**
→ **వార్తా కథనం చదవడం**
→ **లైక్ / వ్యాఖ్య / షేర్**

## వార్తలతో పరస్పర చర్యలు

- వార్త కార్డులు మరియు కథన వివరాల నుంచి ఫోన్‌లోని షేర్ సదుపాయం ద్వారా వార్తలను పంచుకోవచ్చు.
- ప్రతి వినియోగదారుకు సంబంధించిన Firestore రికార్డు ద్వారా లైక్/లైక్ తొలగింపు మరియు లైవ్ కౌంట్ నిర్వహించబడుతుంది.
- వ్యాఖ్యలు చేయడానికి లాగిన్ అయి ఉండాలి.
- వ్యాఖ్యల కోసం వచ్చే లాగిన్ సూచన ద్వారా కొత్త వినియోగదారులు ఖాతాను సృష్టించవచ్చు.
- ప్రతి వార్త కింద వ్యాఖ్యలు నిల్వ చేయబడతాయి మరియు వెంటనే నవీకరించబడతాయి.

---

# వార్తల విభాగాలు మరియు కంటెంట్

వివిధ రకాల వార్తలను సులభంగా కనుగొనడానికి SRI NEWS వార్తలను విభాగాలుగా ఏర్పాటు చేయవచ్చు.

అప్లికేషన్‌లో ఈ వంటి విభాగాలు ఉండవచ్చు:

- తాజా వార్తలు
- జాతీయ వార్తలు
- అంతర్జాతీయ వార్తలు
- రాష్ట్ర వార్తలు
- రాజకీయాలు
- నేర వార్తలు
- వ్యాపారం
- క్రీడలు
- సినిమా / వినోదం
- సాంకేతికత
- ఆరోగ్యం
- విద్య
- జీవనశైలి
- జ్యోతిష్యం / రాశి ఫలాలు
- అప్లికేషన్‌లో ఏర్పాటు చేసిన ఇతర విభాగాలు

అప్లికేషన్‌లో కనిపించే ఖచ్చితమైన విభాగాలు ప్రాజెక్ట్‌లో ఏర్పాటు చేసిన కేటగిరీ డేటాపై ఆధారపడి ఉంటాయి.

---

# వార్తల పోస్టింగ్ మరియు ఆమోదం

## రిపోర్టర్

ఆమోదించబడిన రిపోర్టర్ అప్లికేషన్‌లో అందుబాటులో ఉన్న సమాచారంతో వార్తను సమర్పించవచ్చు:

- వార్త శీర్షిక
- వార్త వివరణ / విషయం
- విభాగం
- చిత్రం / మీడియా
- అందుబాటులో ఉన్న ఇతర వార్తా వివరాలు

సమర్పించిన తర్వాత అధికారం కలిగిన అడ్మిన్ లేదా ఓనర్ పరిశీలించే వరకు వార్త పెండింగ్‌లో ఉండవచ్చు.

## అడ్మిన్ / ఓనర్

నిర్వహణ విభాగం ద్వారా సమర్పించిన వార్తలను పరిశీలించి, ప్రచురించాలా వద్దా నిర్ణయించవచ్చు.

సాధ్యమైన ప్రక్రియ:

- **పెండింగ్** — పరిశీలన కోసం వేచి ఉన్న సమర్పణ.
- **ఆమోదించబడింది** — ప్రచురణకు అంగీకరించబడిన వార్త.
- **తిరస్కరించబడింది** — అంగీకరించని వార్త.
- **ప్రచురించబడింది** — సాధారణ వినియోగదారులకు కనిపించే ఆమోదించిన వార్త.

---

# వినియోగదారు ఖాతాలు

వినియోగదారులు Firebase Authentication ద్వారా ఖాతాలను సృష్టించవచ్చు.

లాగిన్ అయిన వినియోగదారు వ్యాఖ్యలు వంటి Authentication అవసరమైన సదుపాయాలను ఉపయోగించవచ్చు.

అప్లికేషన్ పాత్ర ఆధారంగా ఖాతా:

- వినియోగదారు
- రిపోర్టర్
- అడ్మిన్
- ఓనర్

గా గుర్తించబడుతుంది.

అవసరమైన పాత్ర/అనుమతులు ఉన్న ఖాతాలకే ప్రత్యేక నిర్వహణ సదుపాయాలు అందుబాటులో ఉండాలి.

---

# Firebase

SRI NEWS తన బ్యాక్‌ఎండ్‌గా Firebaseను ఉపయోగిస్తుంది.

## Firebase Authentication

Authentication ఈ పనుల కోసం ఉపయోగించబడుతుంది:

- వినియోగదారు నమోదు.
- వినియోగదారు లాగిన్.
- రక్షిత ఖాతా యాక్సెస్.
- రిపోర్టర్/అడ్మిన్/ఓనర్ Authentication మరియు అనుమతి నిర్వహణ.

వినియోగదారు లాగిన్/వ్యాఖ్యల సదుపాయాలను ఉపయోగించే ముందు Firebase Authenticationలో Email/Password sign-in ప్రారంభించాలి.

## Cloud Firestore

Firestoreలో ఈ వంటి అప్లికేషన్ డేటా నిల్వ చేయబడుతుంది:

- వినియోగదారు ఖాతా/ప్రొఫైల్ సమాచారం.
- పాత్రలు మరియు అనుమతులకు సంబంధించిన డేటా.
- రిపోర్టర్ దరఖాస్తులు.
- వార్తలు/పోస్టులు.
- వార్తల విభాగాలు.
- లైకులు.
- వ్యాఖ్యలు.
- ఇతర అప్లికేషన్ నిర్వహణ డేటా.

లైక్ సమాచారం ప్రతి వినియోగదారుకు Firestoreలో నిల్వ చేయబడుతుంది మరియు లైవ్ కౌంట్ చూపబడుతుంది.

వ్యాఖ్యలు ప్రతి వార్త కింద నిల్వ చేయబడతాయి మరియు వెంటనే నవీకరించబడతాయి.

## Firestore భద్రతా నియమాలు

వివిధ రకాల డేటాను ఎవరు చదవాలి లేదా రాయాలి అనే విషయాన్ని Firestore Security Rules నియంత్రిస్తాయి.

ఈ నియమాలు కింది వాటిని రక్షించాలి:

- వినియోగదారు డేటా.
- రిపోర్టర్ యాక్సెస్.
- అడ్మిన్ కార్యకలాపాలు.
- ఓనర్ కార్యకలాపాలు.
- వార్తల సమర్పణ.
- వార్తల ఆమోదం.
- లైకులు.
- వ్యాఖ్యలు.

Firestore ప్రారంభించిన తర్వాత `firestore.rules`ను Firebaseలో డిప్లాయ్ చేయాలి.

---

# పాత్రలు మరియు అనుమతుల విధానం

సరళమైన అనుమతుల విధానం:

పాత్ర | వార్తలు చదవడం | లైక్ / షేర్ | వ్యాఖ్య | వార్త సమర్పణ | రిపోర్టర్ ఆమోదం | వినియోగదారుల నిర్వహణ | అడ్మిన్ల నిర్వహణ
---|---|---|---|---|---|---|---
వినియోగదారు | అవును | అవును | లాగిన్ అయితే అవును | లేదు | లేదు | లేదు | లేదు
రిపోర్టర్ | అవును | అవును | లాగిన్ అయితే అవును | ఆమోదం తర్వాత అవును | లేదు | లేదు | లేదు
అడ్మిన్ | అవును | అవును | అవును | ఏర్పాటు చేసిన నిర్వహణ అనుమతుల ప్రకారం | అవును | అవును | నియమాల ప్రకారం
ఓనర్ | అవును | అవును | అవును | నిర్వహణ అనుమతులు | అవును | అవును | అవును

తుది అనుమతులు అప్లికేషన్‌లోని Firebase Authentication మరియు Firestore Rules configuration ద్వారా నిర్ణయించబడతాయి.

---

# రక్షిత ఓనర్ / అడ్మిన్ లాగిన్

సాధారణ వినియోగదారు UIలో ఓనర్/అడ్మిన్ లాగిన్ ప్రత్యేకంగా చూపించబడదు.

రక్షిత అడ్మిన్ మార్గాన్ని తెరవడానికి Home headerలోని ఎరుపు **SRI** లోగోను **2 సెకన్లలో 7 సార్లు** నొక్కాలి.

రక్షిత మార్గానికి Firebase ID tokenలో `admin == true` claim అవసరం. అధికారం లేని ఖాతాలు అప్లికేషన్‌లోని అనుమతి నియమాల ప్రకారం తిరస్కరించబడతాయి.

---

# నిర్వహణ విభాగం

నిర్వహణ విభాగం అధికారం కలిగిన ఖాతాల కోసం ఉద్దేశించబడింది.

## ఓనర్ నిర్వహణ

ఓనర్ మొత్తం అప్లికేషన్ మరియు దాని వినియోగదారులు/పాత్రలను నిర్వహించవచ్చు:

- వినియోగదారులు
- అడ్మిన్లు
- రిపోర్టర్లు
- రిపోర్టర్ ఆమోదాలు/తిరస్కరణలు
- రిపోర్టర్ యాక్సెస్ తొలగింపు
- సమర్పించిన వార్తలు
- వార్తల ఆమోదం
- అందుబాటులో ఉన్న నిర్వహణ సదుపాయాలు

## అడ్మిన్ నిర్వహణ

అడ్మిన్ అప్లికేషన్ భద్రతా నియమాలు అనుమతించే కార్యకలాపాలను నిర్వహించవచ్చు:

- వినియోగదారులు
- రిపోర్టర్లు
- రిపోర్టర్ ఆమోదాలు/తిరస్కరణలు
- సమర్పించిన వార్తలు
- వార్తల ఆమోదం
- నిర్వహణ కంటెంట్

## రిపోర్టర్ నిర్వహణ

రిపోర్టర్ యాక్సెస్ ఆమోదం ఆధారంగా ఉంటుంది. రిపోర్టర్ ఖాతా ఆమోదించబడే వరకు అధికారం కలిగిన రిపోర్టర్‌గా వార్తలను సమర్పించకూడదు.

---

# కంటెంట్ భద్రత మరియు పరిశీలన ప్రక్రియ

రిపోర్టర్ సమర్పించిన వార్తలను ప్రచురించే ముందు పరిశీలించడానికి నిర్వహణ ప్రక్రియ రూపొందించబడింది.

**రిపోర్టర్ సమర్పణ**
→ **పెండింగ్**
→ **అడ్మిన్/ఓనర్ పరిశీలన**
→ **ఆమోదం లేదా తిరస్కరణ**
→ **ఆమోదించిన కంటెంట్ ప్రచురణకు సిద్ధం**

దీని ద్వారా ప్రతి సాధారణ వినియోగదారుకు నేరుగా ప్రచురించే అవకాశం ఇవ్వకుండా నియంత్రిత ప్రచురణ విధానం ఉంటుంది.

---

# అప్లికేషన్ నిర్మాణం

సాధారణంగా SRI NEWSలో ఇవి ఉంటాయి:

- హోమ్ పేజీ
- వార్తా కార్డులు
- వార్తా వివరాలు / కథన పేజీ
- ఎక్స్‌ప్లోర్ / విభాగాలు
- వినియోగదారు లాగిన్ / నమోదు
- వ్యాఖ్యల వ్యవస్థ
- రిపోర్టర్ విభాగం
- అడ్మిన్ విభాగం
- ఓనర్ విభాగం
- Firebase Authentication
- Cloud Firestore
- Firestore Security Rules

ఖచ్చితమైన స్క్రీన్లు మరియు ఫైల్ నిర్మాణం ప్రస్తుత Flutter ప్రాజెక్ట్ అమలుపై ఆధారపడి ఉంటుంది.

---

# ప్రధాన అప్లికేషన్ ప్రక్రియ

**SRI NEWS**

**వినియోగదారు విభాగం**
→ హోమ్ / వార్తలు
→ విభాగాల అన్వేషణ
→ వార్తల వివరాలు
→ లైక్ / వ్యాఖ్య / షేర్

**నిర్వహణ విభాగం**
→ ఓనర్ / అడ్మిన్ / రిపోర్టర్
→ పాత్ర ఆధారిత యాక్సెస్
→ రిపోర్టర్ ఆమోదం
→ వార్తల పరిశీలన
→ ప్రచురణ / తిరస్కరణ

---

# డేటా ప్రవాహం

**వినియోగదారు**
→ Firebase Authentication
→ ప్రచురించిన వార్తలు
→ లైక్
→ వ్యాఖ్య
→ షేర్

**రిపోర్టర్**
→ రిపోర్టర్ దరఖాస్తు
→ ఓనర్/అడ్మిన్ ఆమోదం
→ రిపోర్టర్ యాక్సెస్
→ వార్త సమర్పణ
→ ఓనర్/అడ్మిన్ పరిశీలన
→ ప్రచురించిన వార్త

**ఓనర్/అడ్మిన్**
→ వినియోగదారులు
→ రిపోర్టర్లు
→ వార్తలు
→ ఆమోదాలు
→ నిర్వహణ

---

# భద్రతా సూత్రాలు

SRI NEWS ఈ సూత్రాలను పాటించాలి:

1. సాధారణ వినియోగదారులు రక్షిత నిర్వహణ సదుపాయాలను యాక్సెస్ చేయకూడదు.
2. రిపోర్టర్ యాక్సెస్ ఆమోదంపై ఆధారపడి ఉండాలి.
3. రిపోర్టర్ వార్తల సమర్పణ Firestore అనుమతుల ద్వారా నియంత్రించబడాలి.
4. అధికారం కలిగిన అడ్మిన్/ఓనర్ మాత్రమే రిపోర్టర్ దరఖాస్తులను ఆమోదించాలి లేదా తిరస్కరించాలి.
5. అధికారం కలిగిన నిర్వహణ ఖాతాలే కంటెంట్‌ను ప్రచురణకు ఆమోదించాలి.
6. UIపై మాత్రమే ఆధారపడకుండా Firestore Security Rules ద్వారా బ్యాక్‌ఎండ్‌లో అనుమతులు అమలు చేయాలి.
7. రక్షిత వినియోగదారు సదుపాయాల కోసం Firebase Authentication ప్రారంభించి ఉండాలి.

---

# Firebase సెటప్

అప్లికేషన్ ఉపయోగించే ముందు:

1. Firebase ప్రాజెక్ట్‌ను సృష్టించి/కాన్ఫిగర్ చేయాలి.
2. Flutter అప్లికేషన్‌ను Firebaseకు జోడించాలి.
3. Firebase Authentication ప్రారంభించాలి.
4. Email/Password sign-in ప్రారంభించాలి.
5. Cloud Firestore ప్రారంభించాలి.
6. ప్రాజెక్ట్ `firestore.rules`ను డిప్లాయ్ చేయాలి.
7. అవసరమైన పాత్ర/అనుమతి డేటాను కాన్ఫిగర్ చేయాలి.
8. Flutter అప్లికేషన్‌ను అమలు చేయాలి.

---

# ప్రాజెక్ట్ లక్ష్యం

SRI NEWS లక్ష్యం పూర్తి స్థాయి వార్తా వేదికను అందించడం:

- వినియోగదారులు సులభంగా వార్తలను కనుగొని చదవగలగాలి.
- ప్రచురించిన వార్తలతో వినియోగదారులు పరస్పరం వ్యవహరించగలగాలి.
- అనుమతి పొందిన తర్వాత రిపోర్టర్లు వార్తలను సమర్పించగలగాలి.
- అడ్మిన్లు అప్లికేషన్‌ను నిర్వహించి కంటెంట్‌ను పరిశీలించగలగాలి.
- వినియోగదారులు, పాత్రలు, రిపోర్టర్లు మరియు ప్రచురణపై ఓనర్‌కు పూర్తి స్థాయి నిర్వహణ నియంత్రణ ఉండాలి.
- Firebase Authentication, డేటా నిల్వ, లైవ్ అప్‌డేట్లు మరియు బ్యాక్‌ఎండ్ భద్రతను అందించాలి.

---

# ముఖ్యమైన సమాచారం

ఖచ్చితమైన ఫీచర్లు, విభాగాలు, స్క్రీన్లు, అనుమతులు మరియు Firestore field పేర్లు ప్రస్తుత Flutter source code మరియు Firebase configuration ఆధారంగా నిర్ణయించబడతాయి.

ఈ **నిబంధనలు & షరతులు** SRI NEWS అప్లికేషన్ నిర్మాణం మరియు పని విధానాన్ని వివరిస్తాయి. ప్రస్తుత source codeలో అమలు చేయని ఏ ఫీచర్ అయినా సంబంధిత Flutter/Firebase ఫైళ్లలో ప్రత్యేకంగా అమలు చేయాలి.

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
