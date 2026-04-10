String normalizeImageUrl(String url) {
  if (url.isEmpty) return '';
  final cleanUrl = url.trim();
  if (cleanUrl.startsWith('http://')) {
    return cleanUrl.replaceFirst('http://', 'https://');
  }
  if (cleanUrl.startsWith('//')) {
    return 'https:$cleanUrl';
  }
  if (cleanUrl.startsWith('/')) {
    return 'https://bgm.tv$cleanUrl';
  }
  return cleanUrl;
}

Map<String, String> buildImageHeaders(String imageUrl) {
  final normalized = normalizeImageUrl(imageUrl);
  final referer = normalized.contains('chii.in')
      ? 'https://chii.in/'
      : 'https://bgm.tv/';

  return {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': referer,
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Connection': 'keep-alive',
  };
}