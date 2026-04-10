import 'package:flutter/material.dart';
import '../utils/media_cache_manager.dart';
import '../resolvers/local_file_resolver.dart';
import 'video_player_page.dart';

class LocalCachePage extends StatefulWidget {
  const LocalCachePage({super.key});

  @override
  State<LocalCachePage> createState() => _LocalCachePageState();
}

class _LocalCachePageState extends State<LocalCachePage> {
  @override
  void initState() {
    super.initState();
    MediaCacheManager().ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的离线缓存', style: TextStyle(fontSize: 16)),
        elevation: 1,
      ),
      body: AnimatedBuilder(
        animation: MediaCacheManager(),
        builder: (context, child) {
          final tasks = MediaCacheManager().tasks;

          if (tasks.isEmpty) {
            return const Center(
              child: Text('暂无缓存记录', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                subtitle: _buildSubtitle(task),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.status == 1) 
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Colors.blueAccent, size: 28),
                        onPressed: () => _playLocalVideo(task),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => MediaCacheManager().deleteTask(task.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSubtitle(CacheTask task) {
    if (task.status == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          LinearProgressIndicator(value: task.progress),
          const SizedBox(height: 4),
          Text('下载中: ${(task.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: Colors.blue)),
        ],
      );
    } else if (task.status == 2) {
      return const Text('下载失败或被中断', style: TextStyle(fontSize: 11, color: Colors.red));
    } else {
      return const Text('已下载完成', style: TextStyle(fontSize: 11, color: Colors.green));
    }
  }

  void _playLocalVideo(CacheTask task) async {
    final resolver = LocalFileResolver();
    final sourceData = {
      'local_path': task.localPath,
      'title': task.title,
    };

    try {
      final playableMedia = await resolver.resolve(sourceData);
      
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoPlayerPage(media: playableMedia),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法播放本地文件: $e')));
    }
  }
}