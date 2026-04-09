import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/settings_provider.dart';
import '../api/bangumi_api.dart';
import '../api/dio_client.dart';
import 'magnet_config_page.dart';
import 'search_page.dart';

// 全局统一的链接安全格式化方法
String _getSecureImageUrl(String url) {
  if (url.isEmpty) return '';
  String cleanUrl = url.trim();
  if (cleanUrl.startsWith('http://')) {
    return cleanUrl.replaceFirst('http://', 'https://');
  } else if (cleanUrl.startsWith('//')) {
    return 'https:$cleanUrl';
  }
  return cleanUrl;
}

// 统一的图片容错加载组件，已移除自定义请求头以防止防火墙误拦截
Widget _buildSafeImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
}) {
  final secureUrl = _getSecureImageUrl(imageUrl);
  if (secureUrl.isEmpty) {
    return errorWidget ?? Container(width: width, height: height, color: Colors.grey.withValues(alpha: 0.2));
  }
  return CachedNetworkImage(
    imageUrl: secureUrl,
    width: width,
    height: height,
    fit: fit,
    placeholder: (context, url) => Container(width: width, height: height, color: Colors.grey.withValues(alpha: 0.2)),
    errorWidget: (context, url, error) {
      return Image.network(
        secureUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? Container(width: width, height: height, color: Colors.grey.withValues(alpha: 0.2), child: const Icon(Icons.broken_image, color: Colors.grey)),
      );
    },
  );
}

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

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? detailData;
  List<Map<String, String>> realComments = [];
  
  List<dynamic> charactersData = [];
  List<dynamic> staffData = [];
  List<dynamic> relatedData = [];
  
  bool isSummaryExpanded = false;

  bool isLoading = true;
  bool isSyncing = false;
  bool hasFetchedPersonalData = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final bgmUsername = provider.bgmAcc;
    final bgmToken = provider.bgmToken;
    final dio = DioClient().dio;

    Future<List<dynamic>> fetchCharacters() async {
      try {
        final res = await dio.get('https://api.bgm.tv/v0/subjects/${widget.animeId}/characters');
        if (res.statusCode == 200) {
          return res.data as List<dynamic>;
        }
      } catch (_) {}
      return [];
    }

    Future<List<dynamic>> fetchPersons() async {
      try {
        final res = await dio.get('https://api.bgm.tv/v0/subjects/${widget.animeId}/persons');
        if (res.statusCode == 200) {
          return res.data as List<dynamic>;
        }
      } catch (_) {}
      return [];
    }

    Future<List<dynamic>> fetchRelated() async {
      try {
        final res = await dio.get('https://api.bgm.tv/v0/subjects/${widget.animeId}/subjects');
        if (res.statusCode == 200) {
          return res.data as List<dynamic>;
        }
      } catch (_) {}
      return [];
    }

    final results = await Future.wait([
      BangumiApi.getAnimeDetail(widget.animeId),
      BangumiApi.getSubjectComments(widget.animeId),
      fetchCharacters(),
      fetchPersons(),
      fetchRelated(),
    ]);

    final data = results[0] as Map<String, dynamic>?;
    final comments = results[1] as List<Map<String, String>>;
    final chars = results[2] as List<dynamic>;
    final persons = results[3] as List<dynamic>;
    final related = results[4] as List<dynamic>;
    
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
        charactersData = chars;
        staffData = persons;
        relatedData = related;
        isLoading = false;
      });
    }
  }

  void _searchByKeyword(String keyword) {
    if (keyword.trim().isEmpty) {
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => SearchPage(keyword: keyword.trim())
    ));
  }

  Future<void> _syncToCloud() async {
    final bgmToken = Provider.of<SettingsProvider>(context, listen: false).bgmToken;

    if (bgmToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先在设置中配置 Bgm Token！')));
      return;
    }
    if (currentStatus == '未收藏') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择一个更新状态(如：在看)！')));
      return;
    }

    setState(() => isSyncing = true);

    Map<String, dynamic> postData = {
      'type': statusToInt[currentStatus],
      'ep_status': currentEp,
    };
    
    if (widget.subjectType == 1) {
      postData['vol_status'] = currentVol;
    }
    if (currentRate != '暂不打分') {
      postData['rate'] = int.parse(currentRate.replaceAll('分', ''));
    }
    if (commentController.text.isNotEmpty) {
      postData['comment'] = commentController.text;
    }

    bool success = await BangumiApi.updateCollection(widget.animeId, bgmToken, postData);

    if (!mounted) {
      return;
    }

    setState(() => isSyncing = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('云端同步成功'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步失败，请检查 Token 或网络'), backgroundColor: Colors.red));
    }
  }

  Widget _buildProgressAdjuster({required String title, required int value, required VoidCallback onMinus, required VoidCallback onPlus}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryIconColor = isDarkMode ? Colors.blue.shade400 : Theme.of(context).primaryColor;
    final iconColor = isDarkMode ? Colors.green.shade400 : Colors.green;
    final minusIconColor = value > 0 ? (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700) : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(widget.subjectType == 1 ? Icons.menu_book : Icons.ondemand_video, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: Icon(Icons.remove_circle_outline, color: minusIconColor), onPressed: value > 0 ? onMinus : null),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          IconButton(icon: Icon(Icons.add_circle_outline, color: primaryIconColor), onPressed: onPlus),
        ],
      ),
    );
  }

  void _showFullScreenCommentEditor() {
    TextEditingController tempController = TextEditingController(text: commentController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 16))),
                    const Text('长评编辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, elevation: 0),
                      onPressed: () {
                        setState(() => commentController.text = tempController.text);
                        Navigator.pop(context);
                      },
                      child: const Text('确认保存'),
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
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    decoration: const InputDecoration(hintText: '输入评价内容...', border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(String imageUrl, String cnName, String originalName, ThemeData theme) {
    return Stack(
      children: [
        if (imageUrl.isNotEmpty)
          Positioned.fill(
            child: _buildSafeImage(imageUrl: imageUrl, fit: BoxFit.cover),
          ),
        if (imageUrl.isNotEmpty)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8)),
            ),
          ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 10, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildSafeImage(
                  imageUrl: imageUrl,
                  width: 105,
                  height: 150,
                  fit: BoxFit.cover,
                  errorWidget: Container(width: 105, height: 150, color: Colors.grey, child: const Icon(Icons.broken_image)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cnName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.2)),
                    const SizedBox(height: 4),
                    if (originalName.isNotEmpty && originalName != cnName)
                      Text(originalName, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text('${detailData?['rating']?['score'] ?? '暂无评分'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('首播: ${detailData?['date'] ?? '未知'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(widget.subjectType == 2 ? '已出 ${detailData?['eps'] ?? '?'} 集' : '已出 ${detailData?['eps'] ?? '?'} 卷/话', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (detailData?['tags'] != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (detailData!['tags'] as List).take(5).map((tag) {
                          String tagName = tag is Map ? tag['name']?.toString() ?? '' : tag.toString();
                          return InkWell(
                            onTap: () => _searchByKeyword(tagName),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(tagName, style: TextStyle(fontSize: 10, color: theme.primaryColor)),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHorizontalList({
    required BuildContext context,
    required String title,
    required List<dynamic> items,
    required Widget Function(BuildContext, dynamic) itemBuilder,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: items.length,
            itemBuilder: (ctx, index) => itemBuilder(ctx, items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonCard(BuildContext context, dynamic item, bool isCharacter) {
    String name = item['name'] ?? '';
    String relation = item['relation'] ?? (isCharacter ? '角色' : '职位');
    
    String avatarUrl = '';
    // 这里是对先前问题的修复，严格使用大括号包裹逻辑块
    if (item['images'] != null) {
      if (item['images']['grid'] != null) {
        avatarUrl = item['images']['grid'];
      } else if (item['images']['large'] != null) {
        avatarUrl = item['images']['large'];
      }
    }
    
    String subTitle = relation;
    if (isCharacter && item['actors'] != null && (item['actors'] as List).isNotEmpty) {
      var actor = item['actors'][0];
      String actorName = actor is Map ? (actor['name'] ?? '') : actor.toString();
      if (actorName.isNotEmpty) {
        subTitle = 'CV: $actorName';
      }
    }

    return InkWell(
      onTap: () => _searchByKeyword(name),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 65,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: _buildSafeImage(
                  imageUrl: avatarUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: const Icon(Icons.person, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedCard(BuildContext context, dynamic item) {
    String name = item['name_cn'] ?? item['name'] ?? '';
    if (name.isEmpty) {
      name = item['name'] ?? '';
    }
    String relation = item['relation'] ?? '关联';
    
    String imageUrl = '';
    if (item['images'] != null && item['images']['grid'] != null) {
      imageUrl = item['images']['grid'];
    }

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => DetailPage(
            animeId: item['id'],
            initialName: name,
            subjectType: item['type'] ?? 2,
          )
        ));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 65,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildSafeImage(
                imageUrl: imageUrl,
                width: 60,
                height: 80,
                fit: BoxFit.cover,
                errorWidget: Container(width: 60, height: 80, color: Colors.grey.withValues(alpha: 0.2), child: const Icon(Icons.broken_image)),
              ),
            ),
            const SizedBox(height: 6),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(relation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(ThemeData theme) {
    String summary = detailData?['summary'] ?? '暂无简介';
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('剧情简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => isSummaryExpanded = !isSummaryExpanded),
                  child: Text(
                    summary,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                    maxLines: isSummaryExpanded ? null : 4,
                    overflow: isSummaryExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                ),
                if (summary.length > 100)
                  Center(
                    child: IconButton(
                      icon: Icon(isSummaryExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: theme.primaryColor),
                      onPressed: () => setState(() => isSummaryExpanded = !isSummaryExpanded),
                    ),
                  ),
              ],
            ),
          ),
          _buildCompactHorizontalList(
            context: context,
            title: '角色',
            items: charactersData,
            itemBuilder: (ctx, item) => _buildPersonCard(ctx, item, true),
          ),
          _buildCompactHorizontalList(
            context: context,
            title: '制作人员',
            items: staffData,
            itemBuilder: (ctx, item) => _buildPersonCard(ctx, item, false),
          ),
          _buildCompactHorizontalList(
            context: context,
            title: '关联条目',
            items: relatedData,
            itemBuilder: (ctx, item) => _buildRelatedCard(ctx, item),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab(SettingsProvider provider, ThemeData theme, Color highlightBlue, Color highlightOrange) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch, color: highlightBlue, size: 20),
                  const SizedBox(width: 8),
                  const Text('更新状态:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(4)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentStatus,
                          isExpanded: true,
                          items: ['未收藏', '想看', '看过', '在看', '搁置', '抛弃'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) { 
                            if (val != null) {
                              setState(() => currentStatus = val); 
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.star, color: highlightOrange, size: 20),
                  const SizedBox(width: 8),
                  const Text('打分:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(4)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentRate,
                          isExpanded: true,
                          items: rateOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) { 
                            if (val != null) {
                              setState(() => currentRate = val); 
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
              
              if (widget.subjectType == 1) ...[
                _buildProgressAdjuster(title: '看到第几卷 (Vol)', value: currentVol, onMinus: () => setState(() => currentVol--), onPlus: () => setState(() => currentVol++)),
                _buildProgressAdjuster(title: '看到第几话 (Chap)', value: currentEp, onMinus: () => setState(() => currentEp--), onPlus: () => setState(() => currentEp++)),
              ] else ...[
                _buildProgressAdjuster(title: '看到第几集 (Ep)', value: currentEp, onMinus: () => setState(() => currentEp--), onPlus: () => setState(() => currentEp++)),
              ],

              const SizedBox(height: 4),

              Stack(
                children: [
                  TextField(
                    controller: commentController,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                    decoration: InputDecoration(
                      hintText: '写句短评...',
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(icon: Icon(Icons.fullscreen, color: highlightBlue), onPressed: _showFullScreenCommentEditor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: isSyncing ? null : _syncToCloud,
                  icon: isSyncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                  label: Text(isSyncing ? '同步中...' : '保存进度并同步云端', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              if (provider.bgmAcc.isNotEmpty && !hasFetchedPersonalData)
                const Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Text('未获取到您的旧评价，请检查 Bgm 账号是否填为 UID', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsTab(ThemeData theme, Color highlightBlue, Color highlightOrange) {
    if (realComments.isEmpty) {
      return const Center(child: Text('暂无热评或网络加载失败', style: TextStyle(color: Colors.grey, fontSize: 13)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: realComments.length,
      itemBuilder: (context, index) {
        final comment = realComments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(comment['author']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(comment['rate']!, style: TextStyle(color: highlightOrange, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(comment['content']!, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
              const Divider(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String originalName = detailData?['name'] ?? widget.initialName;
    String cnName = detailData?['name_cn'] ?? widget.initialName;
    if (cnName.isEmpty) {
      cnName = originalName;
    }

    String imageUrl = '';
    if (detailData?['images'] != null && detailData?['images']['large'] != null) {
      imageUrl = detailData!['images']['large'].toString();
    }

    final provider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final highlightOrange = isDarkMode ? Colors.orange.shade400 : Colors.orange;
    final highlightBlue = isDarkMode ? Colors.blue.shade400 : Colors.blue;

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Microsoft YaHei', fontFamilyFallback: ['PingFang SC', 'sans-serif']),
      ),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: _buildTopHeader(imageUrl, cnName, originalName, theme),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            labelColor: theme.primaryColor,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: theme.primaryColor,
                            indicatorWeight: 3,
                            tabs: const [
                              Tab(text: '详情'),
                              Tab(text: '进度'),
                              Tab(text: '吐槽'),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: [
                      _buildDetailsTab(theme),
                      _buildProgressTab(provider, theme, highlightBlue, highlightOrange),
                      _buildCommentsTab(theme, highlightBlue, highlightOrange),
                    ],
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
                  if (cnName.isNotEmpty) {
                    nameList.add(cnName);
                  }
                  if (originalName.isNotEmpty && originalName != cnName) {
                    nameList.add(originalName);
                  }

                  final infobox = detailData?['infobox'];
                  if (infobox is List) {
                    for (var item in infobox) {
                      if (item['key'] == '别名') {
                        if (item['value'] is List) {
                          for (var v in item['value']) {
                            if (v['v'] != null && v['v'].toString().isNotEmpty) {
                              nameList.add(v['v'].toString());
                            }
                          }
                        } else if (item['value'] is String) {
                          if (item['value'].toString().isNotEmpty) {
                            nameList.add(item['value'].toString());
                          }
                        }
                      }
                    }
                  }
                  nameList = nameList.toSet().toList();

                  Navigator.push(context, MaterialPageRoute(builder: (context) => MagnetConfigPage(
                    animeName: cnName,
                    aliases: nameList,
                  )));
                },
                icon: const Icon(Icons.rocket_launch, color: Colors.white),
                label: const Text('去搜刮下载', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}