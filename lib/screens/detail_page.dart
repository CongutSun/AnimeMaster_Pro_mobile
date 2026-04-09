import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/settings_provider.dart';
import '../api/bangumi_api.dart';
import 'magnet_config_page.dart';
import 'category_result_page.dart';

class DetailPage extends StatefulWidget {
  final int animeId;
  final String initialName;
  final int subjectType;

  const DetailPage({
    super.key,
    required this.animeId,
    required this.initialName,
    this.subjectType = 2,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? detailData;
  List<Map<String, String>> realComments = [];
  
  List<dynamic> characters = [];
  List<dynamic> persons = [];
  List<dynamic> relations = [];

  bool isLoading = true;
  bool isSyncing = false;
  bool hasFetchedPersonalData = false;
  bool isSummaryExpanded = false; 

  String currentStatus = '未收藏';
  String currentRate = '暂不打分';
  int currentEp = 0;
  int currentVol = 0;

  final TextEditingController commentController = TextEditingController();

  final Map<String, int> statusToInt = {'想看': 1, '看过': 2, '在看': 3, '搁置': 4, '抛弃': 5};
  final Map<int, String> intToStatus = {1: '想看', 2: '看过', 3: '在看', 4: '搁置', 5: '抛弃'};
  final List<String> rateOptions = ['暂不打分', '1分', '2分', '3分', '4分', '5分', '6分', '7分', '8分', '9分', '10分'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    commentController.dispose();
    super.dispose();
  }

  /// 执行并发请求获取所有详情数据
  Future<void> _loadAllData() async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final bgmUsername = provider.bgmAcc;
    final bgmToken = provider.bgmToken;

    final results = await Future.wait([
      BangumiApi.getAnimeDetail(widget.animeId),
      BangumiApi.getSubjectComments(widget.animeId),
      BangumiApi.getSubjectCharacters(widget.animeId),
      BangumiApi.getSubjectPersons(widget.animeId),
      BangumiApi.getSubjectRelations(widget.animeId),
    ]);

    final data = results[0] as Map<String, dynamic>?;
    final comments = results[1] as List<Map<String, String>>;
    final chars = results[2] as List<dynamic>;
    final staff = results[3] as List<dynamic>;
    final rels = results[4] as List<dynamic>;

    if (bgmUsername.isNotEmpty && bgmToken.isNotEmpty) {
      final collectionData = await BangumiApi.getUserCollection(widget.animeId, bgmUsername, bgmToken);
      if (collectionData != null) {
        hasFetchedPersonalData = true;
        final typeData = collectionData['type'];
        final rateData = collectionData['rate'];
        final commentData = collectionData['comment'];

        int typeInt = typeData is int ? typeData : int.tryParse(typeData?.toString() ?? '') ?? 0;
        int rateInt = rateData is int ? rateData : int.tryParse(rateData?.toString() ?? '') ?? 0;
        String commentStr = commentData?.toString() ?? '';

        if (typeInt > 0 && intToStatus.containsKey(typeInt)) {
          currentStatus = intToStatus[typeInt]!;
        }
        if (rateInt > 0) {
          currentRate = '$rateInt分';
        }
        if (commentStr.isNotEmpty) {
          commentController.text = commentStr;
        }

        currentEp = collectionData['ep_status'] ?? 0;
        currentVol = collectionData['vol_status'] ?? 0;
      }
    }

    if (mounted) {
      setState(() {
        detailData = data;
        realComments = comments;
        characters = chars;
        persons = staff;
        relations = rels;
        isLoading = false;
      });
    }
  }

  /// 执行进度及收藏状态的同步操作
  Future<void> _syncToCloud() async {
    final bgmToken = Provider.of<SettingsProvider>(context, listen: false).bgmToken;

    if (bgmToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步失败：Token 缺失或已过期。')));
      return;
    }
    if (currentStatus == '未收藏') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作提示：请先选择一个收藏状态。')));
      return;
    }

    setState(() => isSyncing = true);

    Map<String, dynamic> postData = {
      'type': statusToInt[currentStatus],
    };
    
    if (currentEp > 0) {
      postData['ep_status'] = currentEp;
    }
    if (widget.subjectType == 1 && currentVol > 0) {
      postData['vol_status'] = currentVol;
    }
    if (currentRate != '暂不打分') {
      postData['rate'] = int.parse(currentRate.replaceAll('分', ''));
    }
    if (commentController.text.isNotEmpty) {
      postData['comment'] = commentController.text;
    }

    bool success = await BangumiApi.updateCollection(widget.animeId, bgmToken, postData);

    if (success && widget.subjectType == 2 && currentEp >= 0) {
      await BangumiApi.updateEpisodeStatus(widget.animeId, bgmToken, currentEp);
    }

    if (!mounted) return; 

    setState(() => isSyncing = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('云端数据同步成功。'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步失败：请检查网络连接。'), backgroundColor: Colors.red));
    }
  }

  /// 唤起长评论编辑视图
  void _showFullScreenCommentEditor() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final accentColor = isDarkMode ? Colors.blue.shade400 : theme.primaryColor;
    
    TextEditingController tempController = TextEditingController(text: commentController.text);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85, 
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 16))
                    ),
                    const Text('长评编辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, elevation: 0),
                      onPressed: () {
                        setState(() => commentController.text = tempController.text);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: tempController,
                    maxLines: null, 
                    expands: true,  
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(fontSize: 15, height: 1.6, color: theme.textTheme.bodyLarge?.color),
                    decoration: const InputDecoration(hintText: '在此输入详细评价内容...', border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 路由导航逻辑处理器
  void _navigateToCategorySearch({required String title, required String mode, required dynamic query}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => CategoryResultPage(title: title, searchMode: mode, query: query, searchType: widget.subjectType)
    ));
  }

  void _navigateToRelatedSubject(int subjectId, String name, int type) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => DetailPage(animeId: subjectId, initialName: name, subjectType: type)
    ));
  }

  /// 构建数字进度微调组件
  Widget _buildProgressAdjuster({required String title, required int value, required VoidCallback onMinus, required VoidCallback onPlus}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final accentColor = isDarkMode ? Colors.blue.shade400 : theme.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(widget.subjectType == 1 ? Icons.menu_book : Icons.ondemand_video, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: value > 0 ? theme.textTheme.bodyMedium?.color : theme.disabledColor),
            onPressed: value > 0 ? onMinus : null,
          ),
          SizedBox(
            width: 40,
            child: Text('$value', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: accentColor),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }

  /// 构建横向滑动列表容器
  Widget _buildHorizontalListContainer({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic item) itemBuilder,
    double height = 180,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) => itemBuilder(items[index]),
          ),
        ),
      ],
    );
  }

  /// 构建顶部资料与操作区域
  Widget _buildTopHeader(ThemeData theme) {
    String originalName = detailData?['name'] ?? widget.initialName;
    String cnName = detailData?['name_cn'] ?? widget.initialName;
    if (cnName.isEmpty) cnName = originalName;

    final isDarkMode = theme.brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? Colors.black.withValues(alpha: 0.4) : theme.cardColor.withValues(alpha: 0.85);
    final borderColor = theme.dividerColor.withValues(alpha: 0.5);
    
    final accentColor = isDarkMode ? Colors.blue.shade400 : theme.primaryColor;
    final scoreColor = isDarkMode ? Colors.orange.shade400 : theme.primaryColor;

    final String posterUrl = detailData?['images']?['large'] ?? '';
    final String score = detailData?['rating']?['score']?.toString() ?? '暂无';
    final String totalVotes = detailData?['rating']?['total']?.toString() ?? '0';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: posterUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: posterUrl, width: 110, height: 160, fit: BoxFit.cover)
                      : Container(width: 110, height: 160, color: theme.dividerColor, child: const Icon(Icons.movie, size: 40)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cnName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2, color: theme.textTheme.titleLarge?.color)),
                    const SizedBox(height: 4),
                    if (originalName != cnName)
                      Text(originalName, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(score, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scoreColor)),
                        const SizedBox(width: 4),
                        Text('分 / $totalVotes 人评', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('发行：${detailData?['date'] ?? '未知'}', style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                    Text(widget.subjectType == 2 ? '内容：${detailData?['eps'] ?? '?'} 话' : '内容：${detailData?['eps'] ?? '?'} 卷/章', style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: theme.cardColor,
                          isExpanded: true,
                          value: currentStatus,
                          items: ['未收藏', '想看', '看过', '在看', '搁置', '抛弃']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color))))
                              .toList(),
                          onChanged: (val) { if (val != null) setState(() => currentStatus = val); },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: theme.cardColor,
                          isExpanded: true,
                          value: currentRate,
                          items: rateOptions
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color))))
                              .toList(),
                          onChanged: (val) { if (val != null) setState(() => currentRate = val); },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.subjectType == 1) ...[ 
                _buildProgressAdjuster(title: '阅读进度 (Vol)', value: currentVol, onMinus: () => setState(() => currentVol--), onPlus: () => setState(() => currentVol++)),
                _buildProgressAdjuster(title: '阅读进度 (Chap)', value: currentEp, onMinus: () => setState(() => currentEp--), onPlus: () => setState(() => currentEp++)),
              ] else ...[ 
                _buildProgressAdjuster(title: '观看进度 (Ep)', value: currentEp, onMinus: () => setState(() => currentEp--), onPlus: () => setState(() => currentEp++)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: commentController,
                        style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                        decoration: InputDecoration(
                          hintText: '记录简短评价...', 
                          hintStyle: TextStyle(color: theme.hintColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12), 
                          border: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(icon: Icon(Icons.fullscreen, color: accentColor), onPressed: _showFullScreenCommentEditor, tooltip: '全屏'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 42,
                child: ElevatedButton.icon(
                  onPressed: isSyncing ? null : _syncToCloud,
                  icon: isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload, size: 18),
                  label: Text(isSyncing ? '同步中...' : '保存进度并同步云端', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTab(ThemeData theme) {
    final List<dynamic> rawTags = detailData?['tags'] ?? [];
    final String summary = detailData?['summary'] ?? '暂无内容简介。';
    final isDarkMode = theme.brightness == Brightness.dark;
    
    final chipColor = isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.grey.shade200;
    final accentColor = isDarkMode ? Colors.blue.shade400 : theme.primaryColor;

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const BouncingScrollPhysics(),
      children: [
        if (rawTags.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: rawTags.map((tag) {
                final tagName = tag['name']?.toString() ?? '';
                return ActionChip(
                  label: Text(tagName, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                  backgroundColor: chipColor,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _navigateToCategorySearch(title: tagName, mode: 'tag', query: tagName),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('剧情简介', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                summary,
                maxLines: isSummaryExpanded ? null : 4,
                overflow: isSummaryExpanded ? TextOverflow.visible : TextOverflow.fade,
                style: TextStyle(fontSize: 14, height: 1.6, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
              ),
              if (summary.length > 80)
                GestureDetector(
                  onTap: () => setState(() => isSummaryExpanded = !isSummaryExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(isSummaryExpanded ? '收起' : '展开阅读', style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
        
        _buildHorizontalListContainer(
          title: '角色与声优',
          items: characters,
          height: 160,
          itemBuilder: (item) {
            final int id = item['id'] ?? 0;
            final String name = item['name'] ?? '未知';
            final String actorName = (item['actors'] != null && item['actors'].isNotEmpty) ? item['actors'][0]['name'] : (item['relation'] ?? '');
            final int actorId = (item['actors'] != null && item['actors'].isNotEmpty) ? item['actors'][0]['id'] : 0;
            
            String imgUrl = '';
            if (item['images'] != null && item['images'] is Map) imgUrl = item['images']['grid'] ?? item['images']['large'] ?? '';
            
            return GestureDetector(
              onTap: () {
                if (actorId != 0) {
                  _navigateToCategorySearch(title: actorName, mode: 'person', query: actorId);
                } else {
                  _navigateToCategorySearch(title: name, mode: 'character', query: id);
                }
              },
              child: Container(
                width: 85,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: imgUrl, width: 85, height: 110, fit: BoxFit.cover)
                          : Container(width: 85, height: 110, color: theme.dividerColor, child: const Icon(Icons.person, color: Colors.grey)),
                    ),
                    const SizedBox(height: 6),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                    Text(actorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        ),

        _buildHorizontalListContainer(
          title: '制作人员',
          items: persons,
          height: 160,
          itemBuilder: (item) {
            final int id = item['id'] ?? 0;
            final String name = item['name'] ?? '未知';
            final String relation = item['relation'] ?? '';
            String imgUrl = '';
            if (item['images'] != null && item['images'] is Map) imgUrl = item['images']['grid'] ?? item['images']['large'] ?? '';
            
            return GestureDetector(
              onTap: () => _navigateToCategorySearch(title: name, mode: 'person', query: id),
              child: Container(
                width: 85,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: imgUrl, width: 85, height: 110, fit: BoxFit.cover)
                          : Container(width: 85, height: 110, color: theme.dividerColor, child: const Icon(Icons.engineering, color: Colors.grey)),
                    ),
                    const SizedBox(height: 6),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                    Text(relation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        ),

        _buildHorizontalListContainer(
          title: '关联条目',
          items: relations,
          height: 180,
          itemBuilder: (item) {
            final int id = item['id'] ?? 0;
            final String name = item['name_cn']?.isNotEmpty == true ? item['name_cn'] : (item['name'] ?? '未知');
            final String relation = item['relation'] ?? '';
            final int type = item['type'] ?? 2;
            String imgUrl = '';
            if (item['images'] != null && item['images'] is Map) imgUrl = item['images']['common'] ?? item['images']['grid'] ?? '';
            
            return GestureDetector(
              onTap: () => _navigateToRelatedSubject(id, name, type),
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: imgUrl, width: 100, height: 130, fit: BoxFit.cover)
                          : Container(width: 100, height: 130, color: theme.dividerColor, child: const Icon(Icons.movie, color: Colors.grey)),
                    ),
                    const SizedBox(height: 6),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                    Text(relation, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: accentColor)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentsTab(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final scoreColor = isDarkMode ? Colors.orange.shade400 : theme.primaryColor;

    if (realComments.isEmpty) {
      return const Center(child: Text('暂无相关评论数据。', style: TextStyle(color: Colors.grey, fontSize: 13)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
      physics: const BouncingScrollPhysics(),
      itemCount: realComments.length,
      itemBuilder: (context, index) {
        final comment = realComments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment['author']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(width: 8),
                  Text(comment['rate']!, style: TextStyle(color: scoreColor, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Text(comment['content']!, style: TextStyle(fontSize: 14, height: 1.5, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8))),
              Padding(
                padding: const EdgeInsets.only(top: 12), 
                child: Divider(height: 1, color: theme.dividerColor)
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    final isDarkMode = theme.brightness == Brightness.dark;
    final accentColor = isDarkMode ? Colors.blue.shade400 : theme.primaryColor;

    final provider = Provider.of<SettingsProvider>(context);
    final bgPath = provider.customBgPath;
    final hasGlobalBg = bgPath.isNotEmpty && File(bgPath).existsSync();

    String originalName = detailData?['name'] ?? widget.initialName;
    String cnName = detailData?['name_cn'] ?? widget.initialName;
    if (cnName.isEmpty) cnName = originalName;

    final String posterUrl = detailData?['images']?['large'] ?? '';

    return Theme(
      data: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Microsoft YaHei', fontFamilyFallback: ['PingFang SC', 'sans-serif'])),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: hasGlobalBg
            ? BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(bgPath)),
                  fit: BoxFit.cover,
                  colorFilter: isDarkMode
                      ? ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken)
                      : ColorFilter.mode(Colors.white.withValues(alpha: 0.6), BlendMode.lighten),
                ),
              )
            : BoxDecoration(color: theme.scaffoldBackgroundColor),
          child: isLoading
            ? const Center(child: CircularProgressIndicator()) 
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      title: Text(cnName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
                      pinned: true,
                      elevation: 0,
                    ),
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          if (posterUrl.isNotEmpty)
                            Positioned.fill(
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover),
                                    BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                      child: Container(
                                        color: isDarkMode 
                                            ? Colors.black.withValues(alpha: 0.7) 
                                            : Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          _buildTopHeader(theme),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: accentColor,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: accentColor,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: '详情资料'),
                            Tab(text: '观众评论'),
                          ],
                        ),
                        isDarkMode,
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(theme),
                    _buildCommentsTab(theme),
                  ],
                ),
              ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: widget.subjectType == 1 ? null : Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                List<String> nameList = [];
                if (cnName.isNotEmpty) nameList.add(cnName);
                if (originalName.isNotEmpty && originalName != cnName) nameList.add(originalName);
                final infobox = detailData?['infobox'];
                
                if (infobox is List) {
                  for (var item in infobox) {
                    if (item is Map && item['key'] == '别名') {
                      var val = item['value'];
                      if (val is List) {
                        for (var v in val) {
                          if (v is Map && v['v'] != null) {
                            nameList.add(v['v'].toString());
                          } else if (v is String) {
                            nameList.add(v);
                          }
                        }
                      } else if (val is String && val.isNotEmpty) {
                        nameList.add(val);
                      }
                    }
                  }
                }
                nameList = nameList.toSet().toList(); 
                Navigator.push(context, MaterialPageRoute(builder: (context) => MagnetConfigPage(animeName: cnName, aliases: nameList)));
              },
              icon: const Icon(Icons.search, color: Colors.white),
              label: const Text('前往资源检索', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDarkMode;
  
  _StickyTabBarDelegate(this.tabBar, this.isDarkMode);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: isDarkMode ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}