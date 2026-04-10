import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../api/webdav_api.dart';
import '../resolvers/webdav_resolver.dart';
import '../utils/media_cache_manager.dart'; // 引入缓存管理器
import 'video_player_page.dart';
import 'local_cache_page.dart'; // 引入缓存中心页面

class WebdavBrowserPage extends StatefulWidget {
  final String animeName;

  const WebdavBrowserPage({super.key, required this.animeName});

  @override
  State<WebdavBrowserPage> createState() => _WebdavBrowserPageState();
}

class _WebdavBrowserPageState extends State<WebdavBrowserPage> {
  String currentPath = '/';
  List<webdav.File> files = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAndInitWebDAV();
  }

  Future<void> _checkAndInitWebDAV() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('webdav_url') ?? '';
    final user = prefs.getString('webdav_user') ?? '';
    final pwd = prefs.getString('webdav_pwd') ?? '';

    if (url.isEmpty) {
      _showConfigDialog();
    } else {
      WebDavApi().init(url, user, pwd);
      _loadDirectory(currentPath);
    }
  }

  Future<void> _loadDirectory(String path) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final list = await WebDavApi().listDir(path);
      list.sort((a, b) {
        final aIsDir = a.isDir ?? false;
        final bIsDir = b.isDir ?? false;
        if (aIsDir == bIsDir) return (a.name?.toString() ?? '').compareTo(b.name?.toString() ?? '');
        return aIsDir ? -1 : 1;
      });
      
      if (mounted) {
        setState(() {
          files = list;
          currentPath = path;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败，请检查配置或网络: $e')));
      }
    }
  }

  void _showConfigDialog() {
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();

    SharedPreferences.getInstance().then((prefs) {
      urlCtrl.text = prefs.getString('webdav_url') ?? '';
      userCtrl.text = prefs.getString('webdav_user') ?? '';
      pwdCtrl.text = prefs.getString('webdav_pwd') ?? '';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('配置 WebDAV 网盘'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'WebDAV URL (必须以 /dav/ 结尾)')),
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: '账号 (Username)')),
            TextField(controller: pwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '密码 (Password)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('webdav_url', urlCtrl.text.trim());
              await prefs.setString('webdav_user', userCtrl.text.trim());
              await prefs.setString('webdav_pwd', pwdCtrl.text.trim());
              
              WebDavApi().init(urlCtrl.text.trim(), userCtrl.text.trim(), pwdCtrl.text.trim());
              
              if (!ctx.mounted) return; 
              Navigator.pop(ctx);
              _loadDirectory('/');
            },
            child: const Text('保存并连接'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (currentPath == '/' || currentPath.isEmpty) {
      Navigator.pop(context);
    } else {
      List<String> parts = currentPath.split('/').where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
      String parentPath = parts.isEmpty ? '/' : '/${parts.join('/')}';
      _loadDirectory(parentPath);
    }
  }

  bool _isVideo(String? name) {
    if (name == null) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.avi') || lower.endsWith('.rmvb') || lower.endsWith('.flv');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentPath == '/',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('云端串流: ${widget.animeName}', style: const TextStyle(fontSize: 14)),
              Text(currentPath, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          actions: [
            // 新增：查看离线缓存页面的快捷入口
            IconButton(
              icon: const Icon(Icons.download_done, color: Colors.blueAccent),
              tooltip: '查看离线缓存',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalCachePage())),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '修改 WebDAV 配置',
              onPressed: _showConfigDialog,
            )
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                itemCount: files.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = files[index];
                  final isDir = file.isDir ?? false;
                  final fileName = file.name?.toString();
                  final isVideo = _isVideo(fileName);

                  return ListTile(
                    leading: Icon(
                      isDir ? Icons.folder : (isVideo ? Icons.movie : Icons.insert_drive_file),
                      color: isDir ? Colors.amber : (isVideo ? Colors.blueAccent : Colors.grey),
                      size: 32,
                    ),
                    title: Text(fileName ?? '未知', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    subtitle: isDir ? null : Text(file.mTime?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                    
                    // 新增：视频文件专属的尾部“下载按钮”
                    trailing: isVideo ? IconButton(
                      icon: const Icon(Icons.file_download, color: Colors.blue),
                      onPressed: () {
                        // 构建下载所需的底层参数
                        final streamUrl = WebDavApi().getStreamUrl(file.path?.toString() ?? '');
                        final headers = WebDavApi().getAuthHeaders();
                        
                        // 丢给 Manager 在后台静默下载
                        MediaCacheManager().startDownload(
                          id: file.path?.toString() ?? '',
                          title: fileName ?? '未知视频',
                          url: streamUrl,
                          headers: headers,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已加入离线缓存队列: $fileName'))
                        );
                      },
                    ) : null,

                    onTap: () async {
                      if (isDir) {
                        _loadDirectory(file.path?.toString() ?? '/');
                      } else if (isVideo) {
                        final resolver = WebDavResolver();
                        final sourceData = {
                          'webdav_path': file.path?.toString() ?? '',
                          'title': fileName ?? '正在播放',
                        };

                        try {
                          final playableMedia = await resolver.resolve(sourceData);
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => VideoPlayerPage(media: playableMedia),
                          ));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('解析播放地址失败: $e'))
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('非支持的视频格式')));
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}