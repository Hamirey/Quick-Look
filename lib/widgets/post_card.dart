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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ----------------------------------------------------------------------
        // 1. CENTERED MEDIA / BACKGROUND
        // ----------------------------------------------------------------------
        Container(
          color: const Color(0xFF06070A),
          child:
              widget.tweet.mediaUrl != null && widget.tweet.mediaUrl!.isNotEmpty
                  ? Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.tweet.mediaUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF141720),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white24, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildFallbackBackground(),
                      ),
                    )
                  : _buildFallbackBackground(),
        ),

        // ----------------------------------------------------------------------
        // 2. GRADIENT OVERLAYS (Cinematic Top & Bottom Vignette)
        // ----------------------------------------------------------------------
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.92),
                  ],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ----------------------------------------------------------------------
        // 3. TAP TO OPEN THE ORIGINAL SOURCE
        // ----------------------------------------------------------------------
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.white.withOpacity(0.06),
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
          right: 80,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minimalist Unified Category Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.tweet.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.tweet.sourceLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Caption
              if (widget.tweet.caption != null &&
                  widget.tweet.caption!.isNotEmpty)
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
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13.5,
                        height: 1.4,
                        shadows: const [
                          Shadow(
                            color: Color.fromRGBO(0, 0, 0, 0.8),
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    secondChild: Text(
                      widget.tweet.caption!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13.5,
                        height: 1.4,
                        shadows: const [
                          Shadow(
                            color: Color.fromRGBO(0, 0, 0, 0.8),
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Deep link pill indicator
              InkWell(
                onTap: _launchCanonicalPost,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_rounded,
                          color: Colors.white70, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Open ${widget.tweet.sourceLabel} article/post',
                        style: const TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
            Color(0xFF151824),
            Color(0xFF07080C),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 44,
              color: Colors.white.withOpacity(0.25),
            ),
            const SizedBox(height: 14),
            Text(
              widget.tweet.caption ?? 'Viral Nigerian Update',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
