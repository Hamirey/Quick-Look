import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/viral_tweet.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../widgets/category_selector.dart';
import '../widgets/ugc_safety_dialogs.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  List<ViralTweet> _tweets = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _checkInitialOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialOnboarding() async {
    final isAccepted = await SupabaseService.instance.isTermsAccepted();
    if (!isAccepted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UgcSafetyDialogs.showTermsOfServiceModal(context);
      });
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    final tweets = await SupabaseService.instance.fetchViralTweets(
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() {
        _tweets = tweets;
        _isLoading = false;
      });
    }
  }

  void _onCategoryChanged(String newCategory) {
    if (_selectedCategory == newCategory) return;
    setState(() {
      _selectedCategory = newCategory;
    });
    _loadFeed();
  }

  void _handlePostBlocked(String tweetId, String author) {
    setState(() {
      final cleanAuthor = author.replaceAll('@', '').trim().toLowerCase();
      _tweets.removeWhere((t) =>
          t.tweetId == tweetId ||
          t.author.replaceAll('@', '').trim().toLowerCase() == cleanAuthor);
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ------------------------------------------------------------------
          // 1. VERTICAL TIKTOK-STYLE PAGEVIEW FEED
          // ------------------------------------------------------------------
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E676),
              ),
            )
          else if (_tweets.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.travel_explore_rounded, size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    'No viral $_selectedCategory news found',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back soon or switch categories',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadFeed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh Feed', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _tweets.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final tweet = _tweets[index];
                return PostCard(
                  key: ValueKey(tweet.tweetId),
                  tweet: tweet,
                  onPostBlocked: () => _handlePostBlocked(tweet.tweetId, tweet.author),
                );
              },
            ),

          // ------------------------------------------------------------------
          // 2. TOP FLOATING APP BAR & CATEGORY SELECTOR (Clean header)
          // ------------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Title Row with Refresh Button Only
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Quick Look',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                            onPressed: _loadFeed,
                            tooltip: 'Refresh Feed',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Horizontal Category Pills
                  CategorySelector(
                    selectedCategory: _selectedCategory,
                    onSelect: _onCategoryChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
