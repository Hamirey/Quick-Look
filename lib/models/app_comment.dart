class AppComment {
  final String id;
  final String tweetId;
  final String? userId;
  final String authorName;
  final String commentText;
  final DateTime createdAt;

  AppComment({
    required this.id,
    required this.tweetId,
    this.userId,
    required this.authorName,
    required this.commentText,
    required this.createdAt,
  });

  factory AppComment.fromJson(Map<String, dynamic> json) {
    return AppComment(
      id: json['id'] as String? ?? '',
      tweetId: json['tweet_id'] as String? ?? '',
      userId: json['user_id'] as String?,
      authorName: json['author_name'] as String? ?? 'Anonymous',
      commentText: json['comment_text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tweet_id': tweetId,
      if (userId != null) 'user_id': userId,
      'author_name': authorName,
      'comment_text': commentText,
    };
  }
}
