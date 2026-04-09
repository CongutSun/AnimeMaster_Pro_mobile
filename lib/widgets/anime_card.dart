import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../models/anime.dart';
import '../screens/detail_page.dart';

const Map<String, String> bgmHttpHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Referer': 'https://bgm.tv/',
};

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final bool isTop;

  const AnimeCard({super.key, required this.anime, this.isTop = false});

  @override
  Widget build(BuildContext context) {
    // 智能获取当前是深色还是浅色模式，用于适配骨架屏底色
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(
              animeId: anime.id,
              initialName: anime.nameCn.isNotEmpty ? anime.nameCn : anime.name,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 图片区域：充满剩余空间，绝对对齐
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: anime.imageUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 300),
                  httpHeaders: bgmHttpHeaders, 
                  
                  placeholder: (context, url) => Container(
                    color: placeholderColor,
                    child: const Center(
                      child: Icon(Icons.image_outlined, color: Colors.grey, size: 24),
                    ),
                  ),
                  
                  // ✨ 错误图：即使网络断开或图片被墙，也不会引发红屏崩溃，而是显示优雅的破损图标
                  errorWidget: (context, url, error) => Container(
                    color: placeholderColor,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // 2. 文字区域：固定高度，防止把上面的图片往上顶
          SizedBox(
            height: isTop ? 54 : 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anime.nameCn.isNotEmpty ? anime.nameCn : anime.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isTop && (double.tryParse(anime.score) ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(anime.score, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}