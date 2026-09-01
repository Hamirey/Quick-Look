import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1016),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy & Terms',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBadge('Effective Date: August 30, 2026'),
            const SizedBox(height: 16),
            const Text(
              'Quick Look Privacy Policy & User-Generated Content Terms',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            _buildParagraph(
              'Quick Look is committed to providing a safe, respectful, and entertaining platform for discovering viral news and discussions across Nigerian music, entertainment, technology, and politics.',
            ),
            const Divider(color: Colors.white12, height: 32),

            _buildSectionHeader('1. User-Generated Content (UGC) Policy'),
            _buildParagraph(
              'Quick Look enforces strict, zero-tolerance standards for objectionable content and abusive users, in full compliance with Google Play Store Developer Policies.',
            ),
            _buildBulletPoint('Hate speech, discrimination, harassment, defamation, or bullying.'),
            _buildBulletPoint('Sexually explicit content, pornography, or non-consensual imagery.'),
            _buildBulletPoint('Graphic violence, threats of bodily harm, or encouragement of illegal acts.'),
            _buildBulletPoint('Spam, fraud, malicious links, phishing, or financial scams.'),
            const SizedBox(height: 12),

            _buildSectionHeader('2. Content Moderation & Rapid Removal'),
            _buildParagraph(
              'All reported content is routed to our automated triage and human review queue. Content that violates our community standards will be removed promptly, typically within 24 hours of reporting. Repeatedly offending user accounts will be permanently blocked.',
            ),
            const SizedBox(height: 12),

            _buildSectionHeader('3. In-App Reporting Mechanism'),
            _buildParagraph(
              'Users can report any objectionable viral post or comment at any time by tapping the "Report" flag icon located on each post card and comment item. When submitting a report, users may categorize the violation and provide additional details.',
            ),
            const SizedBox(height: 12),

            _buildSectionHeader('4. Blocking Abusive Users'),
            _buildParagraph(
              'You have the power to block any user or creator immediately. When you block a user:',
            ),
            _buildBulletPoint('All existing posts and comments from that user are instantly hidden from your active feed.'),
            _buildBulletPoint('You will not see any future posts or comments from that user.'),
            _buildBulletPoint('The blocked user is not notified of the block.'),
            const SizedBox(height: 12),

            _buildSectionHeader('5. Data Collection & Privacy'),
            _buildParagraph(
              'Quick Look does not sell your personal data. We collect minimal telemetry necessary to operate the application, including:',
            ),
            _buildBulletPoint('Anonymous device IDs and session tokens to manage your blocklist and submitted comments.'),
            _buildBulletPoint('App interaction counts (likes, dislikes, category selections) to serve trending content.'),
            _buildBulletPoint('Crash logs and performance metrics to ensure app stability.'),
            const SizedBox(height: 12),

            _buildSectionHeader('6. Contact & Support'),
            _buildParagraph(
              'For moderation appeals, safety inquiries, or privacy concerns, please contact our trust & safety team at: safety@quicklookapp.com',
            ),
            const SizedBox(height: 32),

            Center(
              child: Text(
                'Quick Look v1.0.0 • Built with Google Play UGC Compliance',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE50914).withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFE50914), fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
