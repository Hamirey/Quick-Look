import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/viral_tweet.dart';
import 'action_toolbar.dart';

class PostCard extends StatefulWidget {
  final ViralTweet tweet;
  final VoidCallback? onPostBlocked;

  const PostCard({
    super.key,
    required this.tweet,
    this.onPostBlocked,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isExpanded = false;

  Future<void> _launchCanonicalPost() async {
    final uri = Uri.parse(widget.tweet.canonicalXUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'afrobeats':
        return const Color(0xFFFF7A00);
      case 'nollywood':
        return const Color(0xFFE040FB);
      case 'tech':
        return const Color(0xFF00E5FF);
      case 'politics':
        return const Color(0xFF00E676);
      default:
        return const Color(0xFFFF3366);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(widget.tweet.category);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ----------------------------------------------------------------------
        // 1. CENTERED MEDIA / BACKGROUND
        // ----------------------------------------------------------------------
        Container(
          color: const Color(0xFF0D0E12),
          child: widget.tweet.mediaUrl != null && widget.tweet.mediaUrl!.isNotEmpty
              ? Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.tweet.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF1B1D24),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white38),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildFallbackBackground(),
                  ),
                )
              : _buildFallbackBackground(),
        ),

        // ----------------------------------------------------------------------
        // 2. GRADIENT OVERLAYS
        // ----------------------------------------------------------------------
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ----------------------------------------------------------------------
        // 3. TAP TO OPEN X APP OR BROWSER
        // ----------------------------------------------------------------------
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.white.withOpacity(0.08),
              highlightColor: Colors.transparent,
              onTap: _launchCanonicalPost,
            ),
          ),
        ),

        // ----------------------------------------------------------------------
        // 4. BOTTOM-LEFT OVERLAY (Author, Category, Caption)
        // ----------------------------------------------------------------------
        Positioned(
          left: 16,
          right: 84, // Leave space for the action toolbar
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: categoryColor.withOpacity(0.8), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: categoryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.tweet.category.toUpperCase(),
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Author Handle
              GestureDetector(
                onTap: _launchCanonicalPost,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.tweet.author.startsWith('@')
                          ? widget.tweet.author
                          : '@${widget.tweet.author}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Color(0xFF1D9BF0), size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Caption
              if (widget.tweet.caption != null && widget.tweet.caption!.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      widget.tweet.caption!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        shadows: [
                          Shadow(
                            color: Colors.black80,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    secondChild: Text(
                      widget.tweet.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                        shadows: [
                          Shadow(
                            color: Colors.black80,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // Deep link pill indicator
              InkWell(
                onTap: _launchCanonicalPost,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, color: Colors.white70, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Tap to view thread on X',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ----------------------------------------------------------------------
        // 5. RIGHT SIDE ACTION TOOLBAR
        // ----------------------------------------------------------------------
        Positioned(
          right: 12,
          bottom: 24,
          child: ActionToolbar(
            tweet: widget.tweet,
            onPostBlocked: widget.onPostBlocked,
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            Color(0xFF1E2230),
            Color(0xFF0F1016),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 54,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              widget.tweet.caption ?? 'Viral discussion trending now',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
