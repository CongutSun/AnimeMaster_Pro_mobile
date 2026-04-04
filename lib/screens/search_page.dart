import 'package:flutter/material.dart';
import '../api/bangumi_api.dart';
import '../models/anime.dart';      
import '../widgets/anime_grid.dart'; 

class SearchPage extends StatefulWidget {
  final String keyword;

  const SearchPage({super.key, required this.keyword});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Anime> searchResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    final rawResults = await BangumiApi.search(widget.keyword);
    if (mounted) {
      setState(() {
        searchResults = rawResults.map((e) => Anime.fromJson(e)).toList();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✨ 自动继承深浅色
      appBar: AppBar(
        title: Text('搜索结果: ${widget.keyword}'),
        elevation: 1, 
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : searchResults.isEmpty
              ? const Center(
                  child: Text(
                    '没有找到相关番剧 🥲\n换个名字试试？',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: AnimeGrid(animeList: searchResults),
                ),
    );
  }
}