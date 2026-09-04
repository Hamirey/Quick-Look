class ViralTweet {
  final String tweetId;
  final String author;
  final String? caption;
  final String? mediaUrl;
  final String? xUrl;
  final String category;
  int appLikes;
  int appDislikes;
  int appCommentsCount;
  final DateTime createdAt;

  ViralTweet({
    required this.tweetId,
    required this.author,
    this.caption,
    this.mediaUrl,
    this.xUrl,
    required this.category,
    this.appLikes = 0,
    this.appDislikes = 0,
    this.appCommentsCount = 0,
    required this.createdAt,
  });

  factory ViralTweet.fromJson(Map<String, dynamic> json) {
    return ViralTweet(
      tweetId: json['tweet_id'] as String,
      author: json['author'] as String? ?? 'Unknown',
      caption: json['caption'] as String?,
      mediaUrl: json['media_url'] as String?,
      xUrl: json['x_url'] as String?,
      category: json['category'] as String? ?? 'Afrobeats',
      appLikes: (json['app_likes'] as num?)?.toInt() ?? 0,
      appDislikes: (json['app_dislikes'] as num?)?.toInt() ?? 0,
      appCommentsCount: (json['app_comments_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tweet_id': tweetId,
      'author': author,
      'caption': caption,
      'media_url': mediaUrl,
      'x_url': xUrl,
      'category': category,
      'app_likes': appLikes,
      'app_dislikes': appDislikes,
      'app_comments_count': appCommentsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get canonicalXUrl {
    if (xUrl != null && xUrl!.isNotEmpty) {
      return xUrl!;
    }
    final cleanAuthor = author.replaceAll('@', '').trim();
    return 'https://x.com/$cleanAuthor/status/$tweetId';
  }

  String get sourceLabel {
    final host = Uri.tryParse(canonicalXUrl)?.host.toLowerCase() ?? '';
    if (host.contains('bsky.app')) return 'Bluesky';
    if (host.contains('mastodon')) return 'Mastodon';
    if (host.contains('news.google')) return 'Google News';
    if (host.isNotEmpty) return host.replaceFirst('www.', '');
    return 'Source';
  }
}
