import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/viral_tweet.dart';
import '../services/supabase_service.dart';
import 'comments_sheet.dart';
import 'ugc_safety_dialogs.dart';
import '../screens/privacy_policy_screen.dart';

class ActionToolbar extends StatefulWidget {
  final ViralTweet tweet;
  final VoidCallback? onPostBlocked;

  const ActionToolbar({
    super.key,
    required this.tweet,
    this.onPostBlocked,
  });

  @override
  State<ActionToolbar> createState() => _ActionToolbarState();
}

class _ActionToolbarState extends State<ActionToolbar> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _isDisliked = false;
  late int _likes;
  late int _dislikes;
  late int _commentsCount;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _likes = widget.tweet.appLikes;
    _dislikes = widget.tweet.appDislikes;
    _commentsCount = widget.tweet.appCommentsCount;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likes = (_likes > 0) ? _likes - 1 : 0;
      } else {
        _isLiked = true;
        _likes += 1;
        if (_isDisliked) {
          _isDisliked = false;
          _dislikes = (_dislikes > 0) ? _dislikes - 1 : 0;
        }
        _animController.forward().then((_) => _animController.reverse());
      }
      widget.tweet.appLikes = _likes;
      widget.tweet.appDislikes = _dislikes;
    });

    SupabaseService.instance.incrementLike(widget.tweet.tweetId, _likes);
  }

  void _toggleDislike() {
    setState(() {
      if (_isDisliked) {
        _isDisliked = false;
        _dislikes = (_dislikes > 0) ? _dislikes - 1 : 0;
      } else {
        _isDisliked = true;
        _dislikes += 1;
        if (_isLiked) {
          _isLiked = false;
          _likes = (_likes > 0) ? _likes - 1 : 0;
        }
      }
      widget.tweet.appLikes = _likes;
      widget.tweet.appDislikes = _dislikes;
    });

    SupabaseService.instance.incrementDislike(widget.tweet.tweetId, _dislikes);
  }

  void _openComments() {
    CommentsSheet.show(
      context,
      tweetId: widget.tweet.tweetId,
      initialCommentCount: _commentsCount,
      onCommentAdded: () {
        setState(() {
          _commentsCount += 1;
          widget.tweet.appCommentsCount = _commentsCount;
        });
      },
    );
  }

  Future<void> _shareToWhatsApp() async {
    final captionSnippet = widget.tweet.caption != null && widget.tweet.caption!.isNotEmpty
        ? widget.tweet.caption!
        : 'Viral update from @${widget.tweet.author}';

    final text = '🔥 *Viral on QuickLook News [${widget.tweet.category}]*\n\n'
        '"$captionSnippet"\n\n'
        '👀 Read full post & comments on X:\n${widget.tweet.canonicalXUrl}\n\n'
        '📲 Shared via Quick Look App';

    await Share.share(
      text,
      subject: 'Viral news: @${widget.tweet.author}',
    );
  }

  Future<void> _openNativeX() async {
    final uri = Uri.parse(widget.tweet.canonicalXUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSafetyMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2029),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Color(0xFFE50914)),
              title: const Text('Report Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Flag hate speech, fake news, explicit media, or spam', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                UgcSafetyDialogs.showReportDialog(
                  context,
                  tweetId: widget.tweet.tweetId,
                  targetDescription: 'Post by @${widget.tweet.author}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_flipped, color: Colors.orangeAccent),
              title: Text('Block @${widget.tweet.author}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Hide this and future posts from this author', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                UgcSafetyDialogs.showBlockUserDialog(
                  context,
                  authorHandle: widget.tweet.author,
                  onBlocked: widget.onPostBlocked,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.cyanAccent),
              title: const Text('Privacy Policy & Guidelines', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Like Button
        _buildActionButton(
          iconWidget: ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? const Color(0xFFFF2D55) : Colors.white,
              size: 34,
            ),
          ),
          label: _formatCount(_likes),
          onTap: _toggleLike,
        ),
        const SizedBox(height: 16),

        // Dislike Button
        _buildActionButton(
          iconWidget: Icon(
            _isDisliked ? Icons.thumb_down : Icons.thumb_down_alt_outlined,
            color: _isDisliked ? Colors.orangeAccent : Colors.white,
            size: 30,
          ),
          label: _formatCount(_dislikes),
          onTap: _toggleDislike,
        ),
        const SizedBox(height: 16),

        // Comments Button
        _buildActionButton(
          iconWidget: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white,
            size: 32,
          ),
          label: _formatCount(_commentsCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 16),

        // Share Button (WhatsApp formatted)
        _buildActionButton(
          iconWidget: const Icon(
            Icons.share_rounded,
            color: Colors.white,
            size: 30,
          ),
          label: 'Share',
          onTap: _shareToWhatsApp,
        ),
        const SizedBox(height: 16),

        // Open in X Button
        _buildActionButton(
          iconWidget: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: const Icon(
              Icons.open_in_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          label: 'Open X',
          onTap: _openNativeX,
        ),
        const SizedBox(height: 16),

        // UGC Moderation & Safety Menu (Report / Block)
        _buildActionButton(
          iconWidget: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white70,
              size: 18,
            ),
          ),
          label: 'Safety',
          onTap: _showSafetyMenu,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            child: iconWidget,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black80,
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
