import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final Map<String, String>? httpHeaders; // 新增：接收网络请求头

  const VideoPlayerPage({
    super.key, 
    required this.videoUrl, 
    required this.title,
    this.httpHeaders,
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

    // 修复 Bug：将授权 Header 显式传入播放器引擎
    player.open(Media(
      widget.videoUrl,
      httpHeaders: widget.httpHeaders,
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
        title: Text(
          widget.title, 
          style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis,
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