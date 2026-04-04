import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart'; 
import '../api/bangumi_api.dart';
import '../models/anime.dart'; 
import 'detail_page.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  List<Anime> collectionList = [];
  bool isLoading = true;

  int currentType = 3;
  int currentSubjectType = 2; 
  String _lastLoadedAcc = ''; 

  final Map<int, String> typeMap = {
    1: '想看 (Wish)',
    2: '看过 (Collect)',
    3: '在看 (Do)',
    4: '搁置 (On_hold)',
    5: '抛弃 (Dropped)'
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<SettingsProvider>(context);
    if (provider.isLoaded && provider.bgmAcc != _lastLoadedAcc) {
      _lastLoadedAcc = provider.bgmAcc;
      if (_lastLoadedAcc.isNotEmpty) {
        _loadCollection();
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadCollection() async {
    setState(() => isLoading = true);
    
    final username = Provider.of<SettingsProvider>(context, listen: false).bgmAcc;

    if (username.isNotEmpty) {
      final rawResults = await BangumiApi.getUserCollectionList(username, type: currentType, subjectType: currentSubjectType);
      if (mounted) {
        setState(() {
          collectionList = rawResults.map((e) => Anime.fromJson(e)).toList();
        });
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _addOneEpisode(int index) async {
    final token = Provider.of<SettingsProvider>(context, listen: false).bgmToken;

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缺少 Token，请先在设置中配置！')));
      return;
    }

    final anime = collectionList[index];
    int currentEp = anime.epStatus;
    int totalEp = anime.eps;

    if (totalEp > 0 && currentEp >= totalEp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已经看完啦！')));
      return;
    }

    setState(() {
      collectionList[index] = Anime(
        id: anime.id,
        name: anime.name,
        nameCn: anime.nameCn,
        imageUrl: anime.imageUrl,
        score: anime.score,
        eps: anime.eps,
        epStatus: currentEp + 1,
      );
    });

    bool success = await BangumiApi.updateEpisodeStatus(anime.id, token, currentEp + 1);
    
    if (!mounted) return; 

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 《${anime.displayName}》 进度已更新为 ${currentEp + 1}'), duration: const Duration(seconds: 1)),
      );
    } else {
      setState(() {
        collectionList[index] = anime;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 同步失败，请检查网络！'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          fontFamily: 'Microsoft YaHei',
          fontFamilyFallback: ['PingFang SC', 'sans-serif'],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的二次元库', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Microsoft YaHei')),
          elevation: 1,
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ToggleButtons(
                constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                borderRadius: BorderRadius.circular(8),
                isSelected: [currentSubjectType == 2, currentSubjectType == 1],
                onPressed: (index) {
                  setState(() => currentSubjectType = index == 0 ? 2 : 1);
                  _loadCollection();
                },
                children: const [Text('📺 番剧', style: TextStyle(fontSize: 12)), Text('📚 书籍', style: TextStyle(fontSize: 12))],
              ),
            )
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: theme.cardColor, 
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(currentSubjectType == 2 ? '追番库' : '书库', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: currentType,
                            items: typeMap.entries.map((e) {
                              return DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(e.value, style: const TextStyle(fontSize: 13, fontFamily: 'Microsoft YaHei')),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => currentType = val);
                                _loadCollection();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: _loadCollection,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('刷新', style: TextStyle(fontFamily: 'Microsoft YaHei')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('💡 提示: 点击标题可查看详情或去下载。', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: theme.dividerColor), 
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.bgmAcc.isEmpty 
                      ? const Center(child: Text('请先在设置中配置 Bgm 账号 🥲', style: TextStyle(color: Colors.grey)))
                      : collectionList.isEmpty
                          ? const Center(child: Text('这个状态下空空如也~', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: collectionList.length,
                              itemBuilder: (context, index) {
                                final anime = collectionList[index];
                                String totalEpStr = anime.eps > 0 ? anime.eps.toString() : '?';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor, 
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.dividerColor),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(
                                                animeId: anime.id, 
                                                initialName: anime.displayName,
                                                subjectType: currentSubjectType,
                                              )));
                                            },
                                            child: Text(
                                              anime.displayName,
                                              style: TextStyle(
                                                fontSize: 15, 
                                                fontWeight: FontWeight.bold, 
                                                color: Colors.blue.shade500,
                                                height: 1.4, 
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // ✨ 修复 2：严格区分进度的话术
                                            Text(
                                              currentSubjectType == 2 
                                                  ? '放送进度: ${anime.epStatus} / $totalEpStr 集'
                                                  : '阅读进度: ${anime.epStatus} / $totalEpStr 话(卷)',
                                              style: const TextStyle(fontSize: 13), 
                                            ),
                                            SizedBox(
                                              height: 32,
                                              child: ElevatedButton(
                                                onPressed: (anime.eps > 0 && anime.epStatus >= anime.eps) ? null : () => _addOneEpisode(index),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  backgroundColor: Colors.orange.shade600,
                                                  foregroundColor: Colors.white,
                                                  disabledBackgroundColor: Colors.grey.shade600, 
                                                  elevation: 0,
                                                ),
                                                child: Text(currentSubjectType == 2 ? '看集 +1' : '看卷/话 +1', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Microsoft YaHei')),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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