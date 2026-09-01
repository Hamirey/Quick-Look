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
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Mutual Exclusion: Like toggles Dislike OFF
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

  // Mutual Exclusion: Dislike toggles Like OFF
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
        // Hollow Like Button
        _buildHollowActionButton(
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border_rounded,
              color: _isLiked ? _greenAccent : Colors.white,
              size: 24,
            ),
          ),
          isActive: _isLiked,
          activeColor: _greenAccent,
          label: _formatCount(_likes),
          onTap: _toggleLike,
        ),
        const SizedBox(height: 16),

        // Hollow Dislike Button
        _buildHollowActionButton(
          icon: Icon(
            _isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
            color: _isDisliked ? const Color(0xFFFFA000) : Colors.white,
            size: 22,
          ),
          isActive: _isDisliked,
          activeColor: const Color(0xFFFFA000),
          label: _formatCount(_dislikes),
          onTap: _toggleDislike,
        ),
        const SizedBox(height: 16),

        // Hollow Comments Button
        _buildHollowActionButton(
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
          label: _formatCount(_commentsCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 16),

        // Hollow Share Button
        _buildHollowActionButton(
          icon: const Icon(
            Icons.share_outlined,
            color: Colors.white,
            size: 22,
          ),
          label: 'Share',
          onTap: _shareToWhatsApp,
        ),
        const SizedBox(height: 16),

        // Hollow Safety Shield with Dropdown Sub-Buttons
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            _buildHollowActionButton(
              icon: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 22,
              ),
              isActive: _isSafetyMenuOpen,
              activeColor: const Color(0xFFE50914),
              label: 'Safety',
              onTap: _toggleSafetyMenu,
            ),

            // Popover Sub-Buttons (Report & Block)
            if (_isSafetyMenuOpen)
              Positioned(
                right: 54,
                bottom: 0,
                child: Container(
                  width: 145,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10131B).withOpacity(0.95),
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
                      // Sub-Button: Report
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
                      // Sub-Button: Block
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

  Widget _buildHollowActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.18) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.white.withOpacity(0.28),
                width: 1.8,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
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
