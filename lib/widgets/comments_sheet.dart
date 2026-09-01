import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_comment.dart';
import '../services/supabase_service.dart';
import 'ugc_safety_dialogs.dart';

class CommentsSheet extends StatefulWidget {
  final String tweetId;
  final int initialCommentCount;
  final VoidCallback onCommentAdded;

  const CommentsSheet({
    super.key,
    required this.tweetId,
    required this.initialCommentCount,
    required this.onCommentAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String tweetId,
    required int initialCommentCount,
    required VoidCallback onCommentAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        tweetId: tweetId,
        initialCommentCount: initialCommentCount,
        onCommentAdded: onCommentAdded,
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _authorController = TextEditingController(text: 'GuestUser');
  final ScrollController _scrollController = ScrollController();

  List<AppComment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _authorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await SupabaseService.instance.fetchComments(widget.tweetId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    // Verify Terms of Service acceptance before interacting
    final isAccepted = await SupabaseService.instance.isTermsAccepted();
    if (!isAccepted) {
      if (!mounted) return;
      final accepted = await UgcSafetyDialogs.showTermsOfServiceModal(context);
      if (!accepted) return;
    }

    setState(() => _isSubmitting = true);

    final author = _authorController.text.trim().isEmpty ? 'Anonymous' : _authorController.text.trim();
    final newComment = await SupabaseService.instance.addComment(
      tweetId: widget.tweetId,
      authorName: author,
      commentText: text,
    );

    if (mounted) {
      if (newComment != null) {
        setState(() {
          _comments.add(newComment);
          _commentController.clear();
          _isSubmitting = false;
        });
        widget.onCommentAdded();

        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment. Please try again.')),
        );
      }
    }
  }

  void _showCommentOptions(AppComment comment) {
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
              leading: const Icon(Icons.report_outlined, color: Color(0xFFE50914)),
              title: const Text('Report this comment', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Flag for review or hate speech / harassment', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                UgcSafetyDialogs.showReportDialog(
                  context,
                  commentId: comment.id,
                  targetDescription: 'Comment by ${comment.authorName}: "${comment.commentText}"',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_flipped, color: Colors.orangeAccent),
              title: Text('Block @${comment.authorName}', style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Hide all comments and posts from this user', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                UgcSafetyDialogs.showBlockUserDialog(
                  context,
                  authorHandle: comment.authorName,
                  onBlocked: () {
                    _loadComments();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF16181F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_comments.length} Comments',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'No comments yet.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to share your thoughts!',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final formattedDate = DateFormat.yMMMd().add_jm().format(comment.createdAt);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar circle
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _getAvatarColor(comment.authorName),
                                  child: Text(
                                    comment.authorName.isNotEmpty
                                        ? comment.authorName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Comment Body
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                comment.authorName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                formattedDate,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.4),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Report / Moderation Menu for comment
                                          GestureDetector(
                                            onTap: () => _showCommentOptions(comment),
                                            child: Icon(
                                              Icons.more_horiz,
                                              size: 18,
                                              color: Colors.white.withOpacity(0.35),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.commentText,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13.5,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E2029),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2F3E),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Add a comment (Respect guidelines)...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSubmitting ? null : _submitComment,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.indigo,
      Colors.teal,
      Colors.purple,
      Colors.amber.shade800,
      Colors.deepOrange,
      Colors.pink,
      Colors.blueGrey,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
