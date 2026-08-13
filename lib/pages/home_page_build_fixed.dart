
import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final service = NewsService();
  int nav = 0;
  String category = 'అన్నీ';
  final cats = const ['అన్నీ','తెలంగాణ','ఆంధ్రప్రదేశ్','దేశం','సినిమా','క్రీడలు','టెక్నాలజీ','బిజినెస్'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _body()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav,
        onDestinationSelected: (v) => setState(() => nav = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: 'Read'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Watch'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }

  Widget _body() {
    if (nav != 0) return Center(child: Text(['Read','Watch','Search','Explore','Account'][nav]));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFD71920), borderRadius: BorderRadius.circular(12)),
            child: const Text('SRI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 9),
          const Text('NEWS', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const Spacer(),
          const Icon(Icons.notifications_none_rounded),
        ]),
      ),
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: cats.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c),
              selected: category == c,
              selectedColor: const Color(0xFFFFE8E9),
              onSelected: (_) => setState(() => category = c),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: StreamBuilder<List<NewsItem>>(
        stream: service.watchNews(category),
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('News error: ${s.error}'));
          final items = s.data ?? [];
          if (items.isEmpty) return const Center(child: Text('No news available'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) => NewsCard(item: items[i]),
          );
        },
      )),
    ]);
  }
}


class NewsCard extends StatelessWidget {
  final NewsItem item;

  const NewsCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl.isNotEmpty)
            Image.network(
              item.imageUrl,
              height: 215,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 215,
                child: Center(
                  child: Icon(Icons.broken_image),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                if (item.breaking)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text('BREAKING'),
                      backgroundColor: Color(0xFFFFE8E9),
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      color: Color(0xFFD71920),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 21,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              item.description,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Icon(Icons.favorite_border),
                SizedBox(width: 18),
                Icon(Icons.mode_comment_outlined),
                SizedBox(width: 18),
                Icon(Icons.share_outlined),
                Spacer(),
                Icon(Icons.bookmark_border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
