import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../api/bangumi_api.dart';
import 'magnet_config_page.dart';

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
  bool isLoading = true;
  bool isSyncing = false; 

  bool hasFetchedPersonalData = false; 

  String currentStatus = '未收藏';
  String currentRate = '暂不打分';
  
  int currentEp = 0;  // 话/章/集
  int currentVol = 0; // 卷/册 (仅书籍有效)

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

    final results = await Future.wait([
      BangumiApi.getAnimeDetail(widget.animeId),
      BangumiApi.getSubjectComments(widget.animeId), 
    ]);

    final data = results[0] as Map<String, dynamic>?;
    final comments = results[1] as List<Map<String, String>>;
    
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
        isLoading = false;
      });
    }
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
    
    // ✨ 核心修复：对于番剧（2），绝不打包 vol_status 参数，避免被服务器 400 拦截
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

    if (!mounted) return; 

    setState(() => isSyncing = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 云端同步成功！'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 同步失败，请检查 Token 或网络。'), backgroundColor: Colors.red));
    }
  }

  Widget _buildProgressAdjuster({required String title, required int value, required VoidCallback onMinus, required VoidCallback onPlus}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryIconColor = isDarkMode ? Colors.blue.shade400 : Theme.of(context).primaryColor;
    final iconColor = isDarkMode ? Colors.green.shade400 : Colors.green;
    
    final minusIconColor = value > 0 
        ? (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700)
        : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(widget.subjectType == 1 ? Icons.menu_book : Icons.ondemand_video, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: minusIconColor),
            onPressed: value > 0 ? onMinus : null,
          ),
          SizedBox(
            width: 40,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: primaryIconColor),
            onPressed: onPlus,
          ),
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
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                    const Text('长评编辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, elevation: 0),
                      onPressed: () {
                        setState(() {
                          commentController.text = tempController.text;
                        });
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
                    decoration: const InputDecoration(
                      hintText: '在这里挥洒你的长篇大论吧...\n(支持自动换行，写完后别忘了点击同步云端哦)',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
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
    if (cnName.isEmpty) cnName = originalName;

    final provider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context); 
    
    final isDarkMode = theme.brightness == Brightness.dark;
    final highlightOrange = isDarkMode ? Colors.orange.shade400 : Colors.orange;
    final highlightBlue = isDarkMode ? Colors.blue.shade400 : Colors.blue;

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          fontFamily: 'Microsoft YaHei',
          fontFamilyFallback: ['PingFang SC', 'sans-serif'],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.subjectType == 2 ? '番剧详情与评价' : '书籍详情与评价', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Microsoft YaHei')),
          elevation: 1,
          centerTitle: true,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      cnName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_outline, color: highlightOrange, size: 20),
                                    const SizedBox(width: 4),
                                    Text('官方评分: ${detailData?['rating']?['score'] ?? '0'}', style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                                const Text('|', style: TextStyle(color: Colors.grey)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month, color: Colors.brown, size: 20),
                                    const SizedBox(width: 4),
                                    Text('首播/出版: ${detailData?['date'] ?? '未知'}', style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(widget.subjectType == 2 ? Icons.tv : Icons.book, color: Colors.grey, size: 20),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.subjectType == 2 
                                        ? '全网放送进度: 已出 ${detailData?['eps'] ?? '?'} 集'
                                        : '全网出版进度: 已出 ${detailData?['eps'] ?? '?'} 卷/话', 
                                    style: const TextStyle(fontSize: 14)
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
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
                                        items: ['未收藏', '想看', '看过', '在看', '搁置', '抛弃']
                                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontFamily: 'Microsoft YaHei'))))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => currentStatus = val);
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
                                        items: rateOptions
                                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontFamily: 'Microsoft YaHei'))))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => currentRate = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(),
                            ),
                            
                            if (widget.subjectType == 1) ...[ 
                              _buildProgressAdjuster(
                                title: '看到第几卷 (Vol)', 
                                value: currentVol, 
                                onMinus: () => setState(() => currentVol--), 
                                onPlus: () => setState(() => currentVol++)
                              ),
                              _buildProgressAdjuster(
                                title: '看到第几话 (Chap)', 
                                value: currentEp, 
                                onMinus: () => setState(() => currentEp--), 
                                onPlus: () => setState(() => currentEp++)
                              ),
                            ] else ...[ 
                              _buildProgressAdjuster(
                                title: '看到第几集 (Ep)', 
                                value: currentEp, 
                                onMinus: () => setState(() => currentEp--), 
                                onPlus: () => setState(() => currentEp++)
                              ),
                            ],

                            const SizedBox(height: 4),

                            Stack(
                              children: [
                                TextField(
                                  controller: commentController,
                                  minLines: 3,
                                  maxLines: 5,
                                  style: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 13, height: 1.5),
                                  decoration: InputDecoration(
                                    hintText: '写句短评，或者点击右下角全屏写长评...',
                                    hintStyle: const TextStyle(fontSize: 13),
                                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 40, 12), 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: IconButton(
                                    icon: Icon(Icons.fullscreen, color: highlightBlue),
                                    tooltip: '全屏长评模式',
                                    onPressed: _showFullScreenCommentEditor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: isSyncing ? null : _syncToCloud,
                                icon: isSyncing 
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.cloud_upload),
                                label: Text(isSyncing ? '数据同步中...' : '保存进度并同步云端', style: const TextStyle(fontFamily: 'Microsoft YaHei', fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                            ),
                            
                            if (provider.bgmAcc.isNotEmpty && !hasFetchedPersonalData)
                              const Padding(
                                padding: EdgeInsets.only(top: 12.0),
                                child: Text('⚠️ 提示：未获取到您的旧评价。如果这不合理，请检查您的 Bgm 账号是否填成了中文昵称 (必须填 UID)', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detailData?['summary'] ?? '暂无简介',
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: theme.dividerColor),
                          ),
                          Row(
                            children: [
                              Icon(Icons.chat, color: highlightBlue, size: 20),
                              const SizedBox(width: 8),
                              Text('网友热评', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: highlightBlue)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (realComments.isEmpty)
                            const Text('暂无热评或网络加载失败 (可能是 chii.in 域名被墙)', style: TextStyle(color: Colors.grey, fontSize: 13))
                          else
                            ...realComments.map((comment) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(comment['author']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(comment['rate']!, style: TextStyle(color: highlightOrange, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(comment['content']!, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
                                ],
                              ),
                            )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
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
                if (cnName.isNotEmpty) nameList.add(cnName);
                if (originalName.isNotEmpty && originalName != cnName) nameList.add(originalName);

                final infobox = detailData?['infobox'];
                if (infobox is List) {
                  for (var item in infobox) {
                    if (item['key'] == '别名') {
                      if (item['value'] is List) {
                        for (var v in item['value']) {
                          if (v['v'] != null && v['v'].toString().isNotEmpty) nameList.add(v['v'].toString());
                        }
                      } else if (item['value'] is String) {
                        if (item['value'].toString().isNotEmpty) nameList.add(item['value'].toString());
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
              label: const Text('去搜刮下载', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Microsoft YaHei')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ),
      ),
    );
  }
}