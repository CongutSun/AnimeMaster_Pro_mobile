import 'package:flutter/material.dart';
import '../screens/search_page.dart';
import '../screens/collection_page.dart';
import '../screens/settings_page.dart';

class TopToolBar extends StatefulWidget {
  const TopToolBar({super.key});

  @override
  State<TopToolBar> createState() => _TopToolBarState();
}

class _TopToolBarState extends State<TopToolBar> {
  final TextEditingController _searchController = TextEditingController();

  void _doSearch() {
    if (_searchController.text.trim().isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => SearchPage(keyword: _searchController.text.trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // ✨ 1. 搜索框：加上 Expanded 让它霸占所有剩余空间
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜番剧、书籍',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  fillColor: theme.cardColor,
                  filled: true,
                ),
                onSubmitted: (_) => _doSearch(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ✨ 2. 搜索按钮：改为精致的正方形图标
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 20),
              onPressed: _doSearch,
            ),
          ),
          const SizedBox(width: 8),

          // ✨ 3. 追番按钮：改为精致的正方形图标
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.video_library, color: Colors.white, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionPage())),
            ),
          ),
          const SizedBox(width: 8),

          // ✨ 4. 设置按钮：改为精致的正方形图标
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            ),
          ),
        ],
      ),
    );
  }
}