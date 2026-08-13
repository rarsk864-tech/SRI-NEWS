
import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../services/news_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFFFFF1EE),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NewsDetailsPage(item: item),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 5),
              child: Text(
                item.category,
                style: const TextStyle(
                  color: _darkRed,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                item.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF211A1A),
                ),
              ),
            ),
            if (item.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),
                child: Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border, size: 29),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.mode_comment_outlined, size: 28),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 28),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.bookmark_border, size: 28),
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

  @override
  Widget build(BuildContext context) {
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
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE9EAED),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                size: 50,
                              ),
                            ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Color(0x66000000),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            bottom: 16,
                            child: Text(
                              'Today',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.category,
                            style: const TextStyle(
                              color: _darkRed,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (dateText.isNotEmpty)
                          Text(
                            dateText,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 31,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF241A1A),
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 17),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.55,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(
                      item.content.isNotEmpty
                          ? item.content
                          : item.description,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.share_outlined, size: 30),
                        ),
                        const SizedBox(width: 12),
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
