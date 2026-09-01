import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/viral_tweet.dart';
import '../services/supabase_service.dart';
import 'comments_sheet.dart';
import 'ugc_safety_dialogs.dart';

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
  bool _isSafetyMenuOpen = false;
  late int _likes;
  late int _dislikes;
  late int _commentsCount;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  static const Color _greenAccent = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _likes = widget.tweet.appLikes;
    _dislikes = widget.tweet.appDislikes;
    _commentsCount = widget.tweet.appCommentsCount;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
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
          SupabaseService.instance.incrementDislike(widget.tweet.tweetId, _dislikes);
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
          SupabaseService.instance.incrementLike(widget.tweet.tweetId, _likes);
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

  void _toggleSafetyMenu() {
    setState(() {
      _isSafetyMenuOpen = !_isSafetyMenuOpen;
    });
  }

  void _reportPost() {
    setState(() => _isSafetyMenuOpen = false);
    UgcSafetyDialogs.showReportDialog(
      context,
      tweetId: widget.tweet.tweetId,
      targetDescription: 'Post by @${widget.tweet.author}',
    );
  }

  void _blockAuthor() {
    setState(() => _isSafetyMenuOpen = false);
    UgcSafetyDialogs.showBlockUserDialog(
      context,
      authorHandle: widget.tweet.author,
      onBlocked: widget.onPostBlocked,
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
        // Native TikTok Like Icon
        _buildNativeActionButton(
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isLiked ? _greenAccent : Colors.white,
              size: 32,
            ),
          ),
          label: _formatCount(_likes),
          onTap: _toggleLike,
        ),
        const SizedBox(height: 18),

        // Native TikTok Dislike Icon
        _buildNativeActionButton(
          icon: Icon(
            _isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
            color: _isDisliked ? const Color(0xFFFFA000) : Colors.white,
            size: 28,
          ),
          label: _formatCount(_dislikes),
          onTap: _toggleDislike,
        ),
        const SizedBox(height: 18),

        // Native TikTok Comment Icon
        _buildNativeActionButton(
          icon: const Icon(
            Icons.mode_comment_outlined,
            color: Colors.white,
            size: 28,
          ),
          label: _formatCount(_commentsCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 18),

        // Native TikTok Share Icon
        _buildNativeActionButton(
          icon: const Icon(
            Icons.share_rounded,
            color: Colors.white,
            size: 28,
          ),
          label: 'Share',
          onTap: _shareToWhatsApp,
        ),
        const SizedBox(height: 18),

        // Native TikTok More/Safety 3-Dots
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            _buildNativeActionButton(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 28,
              ),
              label: 'More',
              onTap: _toggleSafetyMenu,
            ),

            // Popover Sub-Buttons (Report & Block)
            if (_isSafetyMenuOpen)
              Positioned(
                right: 50,
                bottom: 0,
                child: Container(
                  width: 145,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10131B).withOpacity(0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _reportPost,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: const Row(
                            children: [
                              Icon(Icons.flag_outlined, color: Color(0xFFFF453A), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Report Post',
                                style: TextStyle(
                                  color: Color(0xFFFF453A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 4),
                      InkWell(
                        onTap: _blockAuthor,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: const Row(
                            children: [
                              Icon(Icons.block_outlined, color: Color(0xFFFF9F0A), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Block User',
                                style: TextStyle(
                                  color: Color(0xFFFF9F0A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNativeActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Center(child: icon),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black,
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
