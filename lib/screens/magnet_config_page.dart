import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../providers/settings_provider.dart'; 
import '../api/magnet_api.dart';

class MagnetConfigPage extends StatefulWidget {
  final String animeName;      
  final List<String> aliases; 

  const MagnetConfigPage({super.key, required this.animeName, required this.aliases});

  @override
  State<MagnetConfigPage> createState() => _MagnetConfigPageState();
}

class _MagnetConfigPageState extends State<MagnetConfigPage> {
  final keywordController = TextEditingController();
  final includeController = TextEditingController();
  final qualityController = TextEditingController();
  final excludeController = TextEditingController();

  List<Map<String, String>> selectedSources = [];
  
  bool isSearching = false;
  List<Map<String, String>> searchResults = [];
  bool hasSearched = false;

  @override
  void initState() {
    super.initState();
    keywordController.text = widget.animeName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSources();
    });
  }

  void _loadSources() {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      selectedSources = List.from(provider.rssSources);
    });
  }

  void _showAliasesDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('选择要搜刮的名称', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.aliases.length,
                    itemBuilder: (context, index) {
                      final name = widget.aliases[index];
                      return ListTile(
                        leading: const Icon(Icons.label_outline, color: Colors.blue),
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          setState(() {
                            keywordController.text = name;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _startSearch() async {
    if (keywordController.text.trim().isEmpty) return;
    if (selectedSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择一个搜刮源！')));
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
      searchResults.clear();
    });

    final results = await MagnetApi.searchTorrents(
      keyword: keywordController.text.trim(),
      selectedSources: selectedSources,
      mustInclude: includeController.text.trim(),
      quality: qualityController.text.trim(),
      exclude: excludeController.text.trim(),
    );

    if (mounted) {
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    }
  }

  void _copyMagnet(String magnet) {
    Clipboard.setData(ClipboardData(text: magnet));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 磁力链接已复制！'), backgroundColor: Colors.green));
  }

  Future<void> _launchMagnetApp(String magnet) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('唤起外部网盘', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '即将呼叫手机内支持磁力链的应用。\n\n'
          '💡 提示：如果弹出系统菜单，请选择你想用的网盘。如果没有反应，可能是未安装兼容应用。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('取消', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('确定前往', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final uri = Uri.parse(magnet);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyMagnet(magnet);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ 唤起失败。已自动复制链接。'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      _copyMagnet(magnet);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ 系统拦截请求。已自动复制链接。'), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSources = Provider.of<SettingsProvider>(context).rssSources;
    final theme = Theme.of(context); 

    return Scaffold(
      appBar: AppBar(
        title: const Text('聚合搜刮配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 1,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. 站点搜索词 (PT站推荐用英文/罗马音):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: keywordController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        fillColor: theme.cardColor, 
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _showAliasesDialog, 
                    icon: const Icon(Icons.list, size: 16),
                    label: const Text('选择搜索词'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('2. 结果必须包含词:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: TextField(
                controller: includeController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  fillColor: theme.cardColor,
                  filled: true,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('3. 选择搜刮源:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: allSources.map((source) {
                final isSelected = selectedSources.any((s) => s['name'] == source['name']);
                return FilterChip(
                  label: Text(source['name']!),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedSources.add(source);
                      } else {
                        selectedSources.removeWhere((s) => s['name'] == source['name']);
                      }
                    });
                  },
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.blueAccent,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('画质:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: qualityController,
                          decoration: InputDecoration(hintText: '如: 1080', contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), fillColor: theme.cardColor, filled: true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('排除:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: excludeController,
                          decoration: InputDecoration(hintText: '如: 繁体', contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), fillColor: theme.cardColor, filled: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isSearching ? null : _startSearch,
                icon: isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.rocket_launch, color: Colors.white),
                label: Text(isSearching ? '正在潜入全网搜刮...' : '开始智能搜刮', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),

            if (hasSearched) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text('🚀 搜刮结果:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (searchResults.isEmpty && !isSearching)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('没有找到符合条件的资源，请尝试精简关键词', style: TextStyle(color: Colors.grey))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final res = searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(side: BorderSide(color: theme.dividerColor), borderRadius: BorderRadius.circular(8)), 
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              res['title']!,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.4, color: Colors.blueAccent),
                            ),
                            const SizedBox(height: 12),
                            // ✨ 核心修复：上下结构排版！
                            // 第一行：显示长长的日期
                            Text(res['date']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            // 第二行：让两个按钮靠右对齐，再也不会被挤出屏幕了！
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.copy, size: 14), 
                                  label: const Text('复制', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), minimumSize: const Size(0, 36)),
                                  onPressed: () => _copyMagnet(res['magnet']!)
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.download_rounded, size: 14), 
                                  label: const Text('网盘', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent, 
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16), 
                                    minimumSize: const Size(0, 36)
                                  ),
                                  onPressed: () => _launchMagnetApp(res['magnet']!)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}