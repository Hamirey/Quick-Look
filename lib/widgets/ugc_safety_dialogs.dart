import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../screens/privacy_policy_screen.dart';

class UgcSafetyDialogs {
  /// Show Terms of Service & Community Guidelines Acceptance Modal
  static Future<bool> showTermsOfServiceModal(BuildContext context) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _TermsOfServiceSheet(),
    );

    return accepted ?? false;
  }

  /// Show Report Content Dialog (for Tweets or Comments)
  static Future<void> showReportDialog(
    BuildContext context, {
    String? tweetId,
    String? commentId,
    required String targetDescription,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => _ReportDialogContent(
        tweetId: tweetId,
        commentId: commentId,
        targetDescription: targetDescription,
      ),
    );
  }

  /// Show Block User Confirmation Dialog
  static Future<bool> showBlockUserDialog(
    BuildContext context, {
    required String authorHandle,
    VoidCallback? onBlocked,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2029),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Color(0xFFE50914), size: 22),
            const SizedBox(width: 8),
            Text(
              'Block $authorHandle?',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'You will no longer see posts, viral updates, or comments from $authorHandle in your feed.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Block User'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SupabaseService.instance.blockUser(blockedHandle: authorHandle);
      onBlocked?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$authorHandle has been blocked and removed from your feed.'),
            backgroundColor: const Color(0xFF1E2029),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }
    return false;
  }
}

class _TermsOfServiceSheet extends StatelessWidget {
  const _TermsOfServiceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF16181F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFE50914), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Community Guidelines & Terms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Look strictly enforces Google Play\'s User-Generated Content (UGC) safety standards. We have zero tolerance for objectionable content or abusive behavior.',
              style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 12),
            _buildRuleItem('🚫 No hate speech, harassment, bullying, or defamation'),
            _buildRuleItem('🛡️ No explicit, graphic, violent, or illegal material'),
            _buildRuleItem('⚡ Immediate moderation & removal of reported violations'),
            _buildRuleItem('🔒 Instant blocking of abusive users and author accounts'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
              child: const Text(
                'Read our full Privacy Policy & Terms of Service →',
                style: TextStyle(
                  color: Color(0xFF1D9BF0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await SupabaseService.instance.acceptTerms();
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'I Agree & Accept',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 13),
      ),
    );
  }
}

class _ReportDialogContent extends StatefulWidget {
  final String? tweetId;
  final String? commentId;
  final String targetDescription;

  const _ReportDialogContent({
    this.tweetId,
    this.commentId,
    required this.targetDescription,
  });

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  final List<String> _reasons = [
    'Hate Speech or Harassment',
    'Misinformation or Fake News',
    'Graphic Violence or Gore',
    'Spam, Scam or Phishing',
    'Sexually Explicit Content',
    'Other Policy Violation',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    await SupabaseService.instance.reportContent(
      tweetId: widget.tweetId,
      commentId: widget.commentId,
      reason: _selectedReason!,
      details: _detailsController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. Content has been reported for immediate review.'),
          backgroundColor: Color(0xFF1E2029),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2029),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Color(0xFFE50914), size: 22),
              SizedBox(width: 8),
              Text(
                'Report Content',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.targetDescription,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a reason for reporting:',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._reasons.map((reason) {
              return RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFFE50914),
                title: Text(reason, style: const TextStyle(color: Colors.white, fontSize: 13)),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (val) => setState(() => _selectedReason = val),
              );
            }),
            const SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Additional details (optional)...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF2C2F3E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: (_selectedReason == null || _isSubmitting) ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
