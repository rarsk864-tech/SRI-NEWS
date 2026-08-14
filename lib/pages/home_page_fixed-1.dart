
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/interaction_service.dart';
import 'user_login_page.dart';
import 'reporter_page.dart';
import 'owner_page.dart';
import 'owner_login_page.dart';

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
          icon: Icon(icons[i], size: 26),
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
              color: _red,
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
              color: Color(0xFF171717),
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const Spacer(),
          IconButton(
            splashRadius: 23,
            onPressed: () {},
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

  NewsItem get item => widget.item;
  bool get featured => widget.featured;
  bool get fullMatter => widget.fullMatter;

  Future<void> _share(BuildContext context) async {
    final text = 'SRI NEWS\n\n${item.title}\n\n${item.description}';
    await Share.share(text, subject: 'SRI NEWS - ${item.title}');
  }

  Future<void> _downloadFullPost(BuildContext context) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final boundary =
          _postKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Post is not ready');

      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('Could not create image');

      await Share.shareXFiles(
        [
          XFile.fromData(
            data.buffer.asUint8List(),
            name: 'sri_news_post.png',
            mimeType: 'image/png',
          ),
        ],
        text: 'SRI NEWS - ${item.title}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full post image ready to save')),
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
  Future<void> _loginRequired(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserLoginPage()),
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
                    _fallbackImage(),
                    Positioned(
                      right: 8,
                      top: 70,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Share',
                          onPressed: () => _share(context),
                          icon: const Icon(
                            Icons.share_outlined,
                            size: 27,
                            color: Color(0xFF493D3D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 4),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      color: _darkRed,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

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
        const _SectionHeader(
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
      'తెలంగాణ',
      'ఆంధ్రప్రదేశ్',
      'దేశం',
      'సినిమా',
      'క్రీడలు',
      'టెక్నాలజీ',
      'బిజినెస్',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      children: [
        const Text(
          'అన్వేషించండి',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'వర్గం ఎంచుకుని ఆ వార్తలను చూడండి',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        ...categories.map(
          (category) => Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.arrow_forward_ios, size: 18),
              title: Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: _bg,
                  builder: (_) => _CategoryNewsSheet(
                    service: service,
                    category: category,
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
                    itemBuilder: (_, i) => NewsCard(item: items[i]),
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

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _openReporter(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReporterPage(),
      ),
    );
  }

  Future<void> _openOwnerLogin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OwnerLoginPage(),
      ),
    );
  }

  Future<void> _openOwnerDashboard(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OwnerPage(),
      ),
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
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _accountAction(
                icon: Icons.person_outline,
                title: 'Login',
                subtitle: 'Login for likes, comments and account features',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserLoginPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _accountAction(
                icon: Icons.edit_note_outlined,
                title: 'Reporter Login / Apply',
                subtitle: 'Reporter account login or application',
                onTap: () => _openReporter(context),
              ),
              const SizedBox(height: 10),
              _accountAction(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Owner Login',
                subtitle: 'Owner dashboard and approvals',
                onTap: () => _openOwnerLogin(context),
              ),
            ],
          );
        }

        final name = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'SRI News User';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (_, userSnapshot) {
            final data = userSnapshot.data?.data() ?? {};
            final role = (data['role'] ?? '').toString().trim().toLowerCase();
            final reporterStatus =
                (data['reporterStatus'] ?? '').toString().trim().toLowerCase();

            final isOwner = role == 'owner';
            final isReporter =
                role == 'reporter' || reporterStatus == 'approved';

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
              children: [
                const Text(
                  'నా ఖాతా',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: _red,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(user.email ?? ''),
                              if (role.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  isOwner
                                      ? 'OWNER'
                                      : isReporter
                                          ? 'REPORTER'
                                          : 'USER',
                                  style: const TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Owner Dashboard is NEVER shown to normal users.
                // Owner Login remains available as the protected entry point.
                if (isOwner)
                  _accountAction(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Owner Dashboard',
                    subtitle: 'Reporter and post approval',
                    onTap: () => _openOwnerDashboard(context),
                  )
                else
                  _accountAction(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Owner Login',
                    subtitle: 'Sign in with the Owner account',
                    onTap: () => _openOwnerLogin(context),
                  ),

                const SizedBox(height: 10),

                if (isReporter)
                  _accountAction(
                    icon: Icons.edit_note_outlined,
                    title: 'Reporter Center',
                    subtitle: 'Create posts and check approval status',
                    onTap: () => _openReporter(context),
                  )
                else
                  _accountAction(
                    icon: Icons.edit_note_outlined,
                    title: 'Reporter Login / Apply',
                    subtitle: reporterStatus == 'pending'
                        ? 'Application waiting for owner approval'
                        : reporterStatus == 'rejected'
                            ? 'Application rejected. You can apply again'
                            : 'Apply to become a reporter',
                    onTap: () => _openReporter(context),
                  ),

                const SizedBox(height: 10),

                _accountAction(
                  icon: Icons.person_outline,
                  title: 'Normal Login',
                  subtitle: 'Account, likes and comments',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserLoginPage(),
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
