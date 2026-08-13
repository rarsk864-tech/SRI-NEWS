
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';
import '../services/interaction_service.dart';
import 'user_login_page.dart';

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
  String category = 'అన్నీ';

  final cats = const [
    'అన్నీ',
    'తెలంగాణ',
    'ఆంధ్రప్రదేశ్',
    'దేశం',
    'సినిమా',
    'క్రీడలు',
    'టెక్నాలజీ',
    'బిజినెస్',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: _body()),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    const labels = ['Read', 'Watch', 'Search', 'Explore', 'Account'];
    const icons = [
      Icons.article_outlined,
      Icons.play_circle_outline,
      Icons.search,
      Icons.explore_outlined,
      Icons.person_outline,
    ];

    return NavigationBar(
      backgroundColor: const Color(0xFFFFEEEA),
      indicatorColor: const Color(0xFFFFD9D5),
      selectedIndex: nav,
      height: 74,
      onDestinationSelected: (v) => setState(() => nav = v),
      destinations: List.generate(
        labels.length,
        (i) => NavigationDestination(
          icon: Icon(icons[i]),
          selectedIcon: Icon(icons[i]),
          label: labels[i],
        ),
      ),
    );
  }

  Widget _body() {
    switch (nav) {
      case 1:
        return const WatchPage();
      case 2:
        return const SearchPage();
      case 3:
        return const ExplorePage();
      case 4:
        return const AccountPage();
      default:
        return _readPage();
    }
  }

  Widget _readPage() {
    return Column(
      children: [
        _header(),
        _categoryBar(),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<NewsItem>>(
            stream: service.watchNews(category),
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

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: items.length,
                itemBuilder: (_, i) => NewsCard(item: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'SRI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'NEWS',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: cats.map((c) {
          final selected = category == c;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c),
              selected: selected,
              showCheckmark: selected,
              selectedColor: const Color(0xFFFFE1DE),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected
                    ? const Color(0xFFFFE1DE)
                    : const Color(0xFFE3D7D4),
              ),
              labelStyle: TextStyle(
                color: selected ? _darkRed : Colors.black87,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
              onSelected: (_) => setState(() => category = c),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final NewsItem item;

  const NewsCard({super.key, required this.item});

  Future<void> _share(BuildContext context) async {
    final url = 'https://sri-news-34bde.web.app/news/${item.id}';
    final text = 'SRI NEWS\\n\\n${item.title}\\n\\n${item.description}\\n\\nRead full story:\\n$url';
    await Share.share(text, subject: 'SRI NEWS - ${item.title}');
  }

  Future<void> _loginRequired(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserLoginPage()),
    );
  }

  Future<void> _comment(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _loginRequired(context);
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) return;
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
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) return;
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

  @override
  Widget build(BuildContext context) {
    final interactions = InteractionService();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NewsDetailsPage(item: item)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.imageUrl.isNotEmpty)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Image.network(
                          item.imageUrl,
                          width: double.infinity,
                          height: 205,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 205,
                            color: const Color(0xFFE9EAED),
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                      if (item.breaking)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BREAKING',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 5),
                  child: Text(
                    item.category,
                    style: const TextStyle(color: _darkRed, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 23, height: 1.25, fontWeight: FontWeight.w900),
                  ),
                ),
                if (item.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),
                    child: Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, height: 1.45, color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                StreamBuilder<bool>(
                  stream: interactions.likedByMe(item.id),
                  builder: (_, liked) => IconButton(
                    tooltip: 'Like',
                    onPressed: () => _like(context),
                    icon: Icon(
                      liked.data == true ? Icons.favorite : Icons.favorite_border,
                      color: liked.data == true ? _red : Colors.black87,
                      size: 28,
                    ),
                  ),
                ),
                StreamBuilder<int>(
                  stream: interactions.likeCount(item.id),
                  builder: (_, count) => Text('${count.data ?? 0}'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Comment',
                  onPressed: () => _comment(context),
                  icon: const Icon(Icons.mode_comment_outlined, size: 27),
                ),
                StreamBuilder<int>(
                  stream: interactions.commentCount(item.id),
                  builder: (_, count) => Text('${count.data ?? 0}'),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_outlined, size: 27),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Bookmark',
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_border, size: 27),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewsDetailsPage extends StatelessWidget {
  final NewsItem item;

  const NewsDetailsPage({super.key, required this.item});

  String get dateText {
    final date = item.publishedAt;
    if (date == null) return item.time;
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    if (item.time.isEmpty) return '$d/$m/${date.year}';
    return '$d/$m/${date.year}  ${item.time}';
  }

  Future<void> _share(BuildContext context) {
    final url = 'https://sri-news-34bde.web.app/news/${item.id}';
    final text = 'SRI NEWS\\n\\n${item.title}\\n\\n${item.description}\\n\\nRead full story:\\n$url';
    return Share.share(text, subject: 'SRI NEWS - ${item.title}');
  }

  Future<void> _comment(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserLoginPage()),
      );
      if (!context.mounted || FirebaseAuth.instance.currentUser == null) return;
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

  @override
  Widget build(BuildContext context) {
    final interactions = InteractionService();
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: item.imageUrl.isNotEmpty ? 330 : 74,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: item.imageUrl.isEmpty
                    ? const SizedBox.shrink()
                    : Image.network(item.imageUrl, fit: BoxFit.cover),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.category,
                              style: const TextStyle(color: _darkRed, fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                        if (dateText.isNotEmpty)
                          Text(dateText, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(item.title, style: const TextStyle(fontSize: 31, height: 1.25, fontWeight: FontWeight.w900)),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 17),
                      Text(item.description, style: TextStyle(fontSize: 18, height: 1.55, color: Colors.grey.shade700)),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(item.content.isNotEmpty ? item.content : item.description,
                        style: const TextStyle(fontSize: 18, height: 1.7, color: Colors.black87)),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        StreamBuilder<bool>(
                          stream: interactions.likedByMe(item.id),
                          builder: (_, liked) => IconButton(
                            onPressed: () async {
                              if (FirebaseAuth.instance.currentUser == null) {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserLoginPage()));
                                if (!context.mounted || FirebaseAuth.instance.currentUser == null) return;
                              }
                              await interactions.toggleLike(item.id);
                            },
                            icon: Icon(liked.data == true ? Icons.favorite : Icons.favorite_border,
                                color: liked.data == true ? _red : Colors.black87, size: 30),
                          ),
                        ),
                        StreamBuilder<int>(
                          stream: interactions.likeCount(item.id),
                          builder: (_, s) => Text('${s.data ?? 0}'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _comment(context),
                          icon: const Icon(Icons.mode_comment_outlined, size: 30),
                        ),
                        StreamBuilder<int>(
                          stream: interactions.commentCount(item.id),
                          builder: (_, s) => Text('${s.data ?? 0}'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _share(context),
                          icon: const Icon(Icons.share_outlined, size: 30),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.bookmark_border, size: 30),
                        ),
                      ],
                    ),
                  ],
                ),
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
    return const _SimpleSection(
      title: 'వీడియోలు',
      subtitle: 'తాజా వీడియో వార్తలు',
      icon: Icons.play_circle_outline,
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleSection(
      title: 'శోధించండి',
      subtitle: 'వార్తలు వెతకండి',
      icon: Icons.search,
    );
  }
}

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('తెలంగాణ', Icons.location_on_outlined),
      ('ఆంధ్రప్రదేశ్', Icons.map_outlined),
      ('జాతీయం', Icons.account_balance_outlined),
      ('అంతర్జాతీయం', Icons.public),
      ('ఆర్థికం', Icons.currency_rupee),
      ('క్రీడలు', Icons.sports_cricket_outlined),
      ('సినిమా', Icons.movie_outlined),
      ('టెక్నాలజీ', Icons.devices_outlined),
      ('బిజినెస్', Icons.business_center_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'అన్వేషించండి',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .95,
            ),
            itemBuilder: (_, i) {
              final item = items[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7E7E7)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.$2, size: 30, color: _blue),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 30),
      children: [
        const Text(
          'నా ఖాతా',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _red,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sri News User',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text('SRI News'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...[
          'నా బుక్‌మార్క్‌లు',
          'నాకు నచ్చిన వార్తలు',
          'చదివిన వార్తలు',
          'నోటిఫికేషన్ సెట్టింగ్స్',
          'భాష',
          'డార్క్ మోడ్',
          'సహాయం & మద్దతు',
        ].map(
          (title) => Card(
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.chevron_right),
              title: Text(title),
              trailing: const Icon(Icons.arrow_forward_ios, size: 15),
              onTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SimpleSection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 55, color: _red),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
