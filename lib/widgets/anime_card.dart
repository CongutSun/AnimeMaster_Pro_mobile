import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../models/anime.dart';
import '../screens/detail_page.dart';
import '../utils/image_request.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final bool isTop;

  const AnimeCard({super.key, required this.anime, this.isTop = false});

  @override
  Widget build(BuildContext context) {
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
                  imageUrl: normalizeImageUrl(anime.imageUrl),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 300),
                  httpHeaders: buildImageHeaders(anime.imageUrl), 
                  
                  placeholder: (context, url) => Container(
                    color: placeholderColor,
                    child: const Center(
                      child: Icon(Icons.image_outlined, color: Colors.grey, size: 24),
                    ),
                  ),
                  
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
          // 修复：增加了底部文字区域的固定高度，完美容纳两行文本，解决 1px 溢出问题
          SizedBox(
            height: isTop ? 64 : 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anime.nameCn.isNotEmpty ? anime.nameCn : anime.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                if (isTop && anime.score.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        anime.score,
                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  Text(
                    anime.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}