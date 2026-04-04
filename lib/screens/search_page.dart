import 'package:flutter/material.dart';
import '../api/bangumi_api.dart';
import '../models/anime.dart';      
import 'detail_page.dart'; // 引入详情页用于直接跳转

class SearchPage extends StatefulWidget {
  final String keyword;

  const SearchPage({super.key, required this.keyword});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Anime> searchResults = [];
  bool isLoading = true;
  int currentSubjectType = 2; // 2为番剧，1为书籍

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() => isLoading = true);
    // 传入当前的搜索类型
    final rawResults = await BangumiApi.search(widget.keyword, type: currentSubjectType);
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
      appBar: AppBar(
        title: Text('搜索: ${widget.keyword}', style: const TextStyle(fontSize: 16)),
        elevation: 1, 
        actions: [
          // 顶部加入番剧/书籍切换按钮
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ToggleButtons(
              constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
              borderRadius: BorderRadius.circular(8),
              isSelected: [currentSubjectType == 2, currentSubjectType == 1],
              onPressed: (index) {
                setState(() => currentSubjectType = index == 0 ? 2 : 1);
                _performSearch();
              },
              children: const [Text('📺 番剧', style: TextStyle(fontSize: 12)), Text('📚 书籍', style: TextStyle(fontSize: 12))],
            ),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : searchResults.isEmpty
              ? Center(
                  child: Text(
                    currentSubjectType == 2 ? '没有找到相关番剧 🥲\n换个名字试试？' : '没有找到相关书籍 🥲\n换个名字试试？',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final anime = searchResults[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                        leading: anime.imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(anime.imageUrl, width: 50, height: 70, fit: BoxFit.cover),
                              )
                            : const SizedBox(width: 50, height: 70, child: Icon(Icons.image_not_supported)),
                        title: Text(anime.displayName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(anime.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          // 将正确的 subjectType 传给详情页
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(
                            animeId: anime.id, 
                            initialName: anime.displayName,
                            subjectType: currentSubjectType,
                          )));
                        },
                      );
                    },
                  )
                ),
    );
  }
}