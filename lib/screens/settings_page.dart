import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/settings_provider.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String themeMode = '明亮模式 (Light)';
  final bgController = TextEditingController();

  final bgmAccController = TextEditingController();
  final bgmTokenController = TextEditingController();

  int selectedRssIndex = -1;
  final rssNameController = TextEditingController();
  final rssUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      bgmAccController.text = provider.bgmAcc;
      bgmTokenController.text = provider.bgmToken;
      
      setState(() {
        themeMode = provider.themeMode;
        bgController.text = provider.customBgPath;
      });
    });
  }

  @override
  void dispose() {
    bgController.dispose();
    bgmAccController.dispose();
    bgmTokenController.dispose();
    rssNameController.dispose();
    rssUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16), 
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪竖屏背景', 
            toolbarColor: Colors.teal.shade700, 
            toolbarWidgetColor: Colors.white, 
            // ✨ 修复：删除了不存在的 initAspectRatio 预设，反正上面已经强制 9:16 了
            lockAspectRatio: true
          ),
          IOSUiSettings(title: '裁剪背景', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          bgController.text = croppedFile.path;
        });
      }
    }
  }

  void _saveSettings() {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    provider.updateAccount(bgmAccController.text, bgmTokenController.text);
    provider.updateAppearance(provider.closeAction, themeMode, bgController.text);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 设置已成功保存并全局应用！'), backgroundColor: Colors.green));
  }

  void _addRss(SettingsProvider provider) {
    if (rssNameController.text.isNotEmpty && rssUrlController.text.contains('{keyword}')) {
      provider.addRssSource(rssNameController.text, rssUrlController.text);
      rssNameController.clear();
      rssUrlController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入站点名，且 URL 必须包含 {keyword}')));
    }
  }

  void _deleteRss(SettingsProvider provider) {
    if (selectedRssIndex >= 0) {
      provider.removeRssSource(selectedRssIndex);
      setState(() => selectedRssIndex = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!provider.isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final uiCard = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎨 界面外观', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 16),
            _buildSettingRow('主题模式:', _buildDropdown(['明亮模式 (Light)', '暗黑模式 (Dark)'], themeMode, (val) => setState(() => themeMode = val!))),
            const SizedBox(height: 12),
            _buildSettingRow('自定义背景:', Row(
              children: [
                Expanded(child: _buildTextField(bgController, readOnly: true, hint: '点击浏览选择图片')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _pickAndCropImage, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white), child: const Text('浏览...')),
              ],
            )),
            const SizedBox(height: 16),
            const Text('背景预览:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              height: 150, 
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                border: Border.all(color: theme.dividerColor, width: 2),
                image: bgController.text.isNotEmpty && File(bgController.text).existsSync() ? DecorationImage(image: FileImage(File(bgController.text)), fit: BoxFit.cover) : null,
              ),
              child: bgController.text.isEmpty ? const Center(child: Text('暂无自定义背景', style: TextStyle(color: Colors.white54))) : null,
            ),
          ],
        ),
      ),
    );

    final accountCard = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👤 Bangumi 账号绑定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            const Text('注意：账号必须是个人主页链接里的 Username 或数字 UID！', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
            const SizedBox(height: 16),
            _buildSettingRow('Bgm 账号:', _buildTextField(bgmAccController, hint: '例如: 123456')),
            const SizedBox(height: 8),
            _buildSettingRow('Bgm Token:', _buildTextField(bgmTokenController, obscureText: true, hint: 'Token')),
          ],
        ),
      ),
    );

    final rssCard = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📡 自定义资源站 (RSS源)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(4)),
              child: ListView.builder(
                itemCount: provider.rssSources.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedRssIndex;
                  return ListTile(
                    dense: true,
                    title: Text('${provider.rssSources[index]['name']} | ${provider.rssSources[index]['url']}'),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withAlpha(25),
                    onTap: () => setState(() => selectedRssIndex = index),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(flex: 3, child: _buildTextField(rssNameController, hint: '站点名')),
                const SizedBox(width: 8),
                Expanded(flex: 7, child: _buildTextField(rssUrlController, hint: '必须包含 {keyword}')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(onPressed: () => _addRss(provider), icon: const Icon(Icons.add, size: 16), label: const Text('添加'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () => _deleteRss(provider), icon: const Icon(Icons.remove, size: 16), label: const Text('删除'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('智能追番助手 设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isMobile 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                uiCard,
                const SizedBox(height: 16),
                accountCard,
                const SizedBox(height: 16),
                rssCard,
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _saveSettings, icon: const Icon(Icons.save), label: const Text('保存并应用', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16))),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: uiCard),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      accountCard,
                      const SizedBox(height: 16),
                      rssCard,
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: _saveSettings, icon: const Icon(Icons.save), label: const Text('保存并应用', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)))),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget child) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)), 
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, {bool obscureText = false, bool readOnly = false, String? hint}) {
    return SizedBox(
      height: 36,
      child: TextField(controller: controller, obscureText: obscureText, readOnly: readOnly, style: const TextStyle(fontSize: 13), decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), border: const OutlineInputBorder())),
    );
  }

  Widget _buildDropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(initialValue: value, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0), border: OutlineInputBorder()), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(), onChanged: onChanged),
    );
  }
}