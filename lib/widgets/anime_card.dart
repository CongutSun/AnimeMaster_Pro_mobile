import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../screens/detail_page.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final bool isTop;

  const AnimeCard({super.key, required this.anime, this.isTop = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(
              // ✨ 核心修复：精准传递详情页需要的 animeId 和 initialName 参数
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
                image: DecorationImage(
                  image: NetworkImage(anime.imageUrl),
                  fit: BoxFit.cover, 
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