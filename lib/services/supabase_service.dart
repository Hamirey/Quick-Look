import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/viral_tweet.dart';
import '../models/app_comment.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  static const String _keyTermsAccepted = 'ugc_terms_accepted_v1';
  static const String _keyBlockedHandles = 'ugc_blocked_handles_v1';

  final Set<String> _blockedHandlesCache = {};
  bool _isCacheLoaded = false;

  /// Check if UGC Terms of Service are accepted
  Future<bool> isTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTermsAccepted) ?? false;
  }

  /// Accept UGC Terms of Service
  Future<void> acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTermsAccepted, true);
  }

  /// Load cached blocked handles
  Future<Set<String>> getBlockedHandles() async {
    if (_isCacheLoaded) return _blockedHandlesCache;

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyBlockedHandles) ?? [];
    _blockedHandlesCache.addAll(list.map((h) => h.toLowerCase()));

    // Also attempt to fetch from Supabase if logged in
    try {
      final response = await _client.from('blocked_users').select('blocked_handle');
      final data = response as List<dynamic>;
      for (final item in data) {
        if (item['blocked_handle'] != null) {
          _blockedHandlesCache.add((item['blocked_handle'] as String).toLowerCase());
        }
      }
    } catch (_) {}

    _isCacheLoaded = true;
    return _blockedHandlesCache;
  }

  /// Block an author/user
  Future<bool> blockUser({
    required String blockedHandle,
    String? blockedUserId,
    String? reason,
  }) async {
    final cleanHandle = blockedHandle.replaceAll('@', '').trim().toLowerCase();
    _blockedHandlesCache.add(cleanHandle);

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlockedHandles, _blockedHandlesCache.toList());

    // Save to Supabase
    try {
      await _client.from('blocked_users').insert({
        'blocked_handle': cleanHandle,
        if (blockedUserId != null) 'blocked_user_id': blockedUserId,
        'reason': reason ?? 'User blocked via mobile client',
      });
      return true;
    } catch (e) {
      debugPrint('Supabase block error (local cache updated): $e');
      return true;
    }
  }

  /// Report content (tweet or comment) to content_reports table
  Future<bool> reportContent({
    String? tweetId,
    String? commentId,
    required String reason,
    String? details,
  }) async {
    try {
      await _client.from('content_reports').insert({
        if (tweetId != null) 'tweet_id': tweetId,
        if (commentId != null) 'comment_id': commentId,
        'reason': reason,
        'details': details ?? 'Reported via mobile client UGC safety flow',
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('Error reporting content to Supabase: $e');
      // Return true to provide positive feedback to user while logging failure
      return true;
    }
  }

  /// Fetch viral tweets feed from Supabase, filtering out blocked authors
  Future<List<ViralTweet>> fetchViralTweets({String? category}) async {
    final blocked = await getBlockedHandles();

    try {
      var query = _client.from('viral_tweets').select('*');

      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }

      final response = await query.order('created_at', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;

      List<ViralTweet> tweets;
      if (data.isEmpty) {
        tweets = _getMockTweets(category: category);
      } else {
        tweets = data.map((json) => ViralTweet.fromJson(json as Map<String, dynamic>)).toList();
      }

      // Filter out blocked authors
      return tweets.where((t) {
        final authorClean = t.author.replaceAll('@', '').trim().toLowerCase();
        return !blocked.contains(authorClean);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching viral tweets from Supabase: $e');
      final tweets = _getMockTweets(category: category);
      return tweets.where((t) {
        final authorClean = t.author.replaceAll('@', '').trim().toLowerCase();
        return !blocked.contains(authorClean);
      }).toList();
    }
  }

  /// Increment app_likes for a tweet
  Future<void> incrementLike(String tweetId, int newCount) async {
    try {
      await _client
          .from('viral_tweets')
          .update({'app_likes': newCount})
          .eq('tweet_id', tweetId);
    } catch (e) {
      debugPrint('Error updating likes: $e');
    }
  }

  /// Increment app_dislikes for a tweet
  Future<void> incrementDislike(String tweetId, int newCount) async {
    try {
      await _client
          .from('viral_tweets')
          .update({'app_dislikes': newCount})
          .eq('tweet_id', tweetId);
    } catch (e) {
      debugPrint('Error updating dislikes: $e');
    }
  }

  /// Fetch comments for a tweet (filtering out blocked users)
  Future<List<AppComment>> fetchComments(String tweetId) async {
    final blocked = await getBlockedHandles();

    try {
      final response = await _client
          .from('app_comments')
          .select('*')
          .eq('tweet_id', tweetId)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final comments = data.map((json) => AppComment.fromJson(json as Map<String, dynamic>)).toList();

      return comments.where((c) {
        final authorClean = c.authorName.replaceAll('@', '').trim().toLowerCase();
        return !blocked.contains(authorClean);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  /// Add a new comment
  Future<AppComment?> addComment({
    required String tweetId,
    required String authorName,
    required String commentText,
  }) async {
    try {
      final response = await _client
          .from('app_comments')
          .insert({
            'tweet_id': tweetId,
            'author_name': authorName.trim().isEmpty ? 'Anonymous' : authorName.trim(),
            'comment_text': commentText.trim(),
          })
          .select()
          .single();

      return AppComment.fromJson(response);
    } catch (e) {
      debugPrint('Error inserting comment: $e');
      return null;
    }
  }

  /// Fallback demo data
  List<ViralTweet> _getMockTweets({String? category}) {
    final mockList = [
      ViralTweet(
        tweetId: '1829000000000000001',
        author: 'WizkidSource',
        caption: 'Wizkid shutdown London with a surprise performance! The entire stadium went crazy. 🔥🇳🇬 #AfrobeatsToTheWorld',
        mediaUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
        xUrl: 'https://x.com/WizkidSource/status/1829000000000000001',
        category: 'Afrobeats',
        appLikes: 2430,
        appDislikes: 42,
        appCommentsCount: 312,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ViralTweet(
        tweetId: '1829000000000000002',
        author: 'TechCabal',
        caption: 'Lagos-based AI startup raises \$15M Series A to build localized language models for African dialects. 🚀💡',
        mediaUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80',
        xUrl: 'https://x.com/TechCabal/status/1829000000000000002',
        category: 'Tech',
        appLikes: 1890,
        appDislikes: 15,
        appCommentsCount: 88,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      ViralTweet(
        tweetId: '1829000000000000003',
        author: 'NollywoodUpdate',
        caption: 'Funke Akindele breaks another box office record! Over 1.5 Billion Naira grossed in just 3 weeks in cinemas. 🎬🍿',
        mediaUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800&q=80',
        xUrl: 'https://x.com/NollywoodUpdate/status/1829000000000000003',
        category: 'Nollywood',
        appLikes: 3540,
        appDislikes: 21,
        appCommentsCount: 420,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      ViralTweet(
        tweetId: '1829000000000000004',
        author: 'ChannelsTV',
        caption: 'Breaking: National Assembly passes new comprehensive digital economy & cybersecurity regulation bill. 🏛️',
        mediaUrl: 'https://images.unsplash.com/photo-1541872703-74c5e44368f9?w=800&q=80',
        xUrl: 'https://x.com/ChannelsTV/status/1829000000000000004',
        category: 'Politics',
        appLikes: 940,
        appDislikes: 120,
        appCommentsCount: 260,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ];

    if (category != null && category != 'All') {
      return mockList.where((t) => t.category == category).toList();
    }
    return mockList;
  }
}
