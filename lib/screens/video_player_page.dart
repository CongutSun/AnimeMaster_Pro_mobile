import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/playable_media.dart'; // 引入新架构的模型

class VideoPlayerPage extends StatefulWidget {
  final PlayableMedia media; // 核心改变：统一接收 PlayableMedia 对象

  const VideoPlayerPage({
    super.key, 
    required this.media,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    // 从统一的 media 对象中提取数据播放
    player.open(Media(
      widget.media.url,
      httpHeaders: widget.media.headers,
    ));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            // 如果是本地缓存视频，显示一个小图标提示
            if (widget.media.isLocal) 
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.offline_pin, color: Colors.green, size: 16),
              ),
            Expanded(
              child: Text(
                widget.media.title, 
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Video(
          controller: controller,
          controls: MaterialVideoControls, 
        ),
      ),
    );
  }
}