// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareReelBottomSheet extends StatelessWidget {
  final String videoUrl;
  final String videoTitle;

  const ShareReelBottomSheet({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
  });

  Future<void> _shareToWhatsApp() async {
    final String text = 'Check out this First Aid Reel: $videoTitle\n$videoUrl';
    final Uri url = Uri.parse(
        'https://www.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
    await _launchUrlOrFallback(url, text);
  }

  Future<void> _shareToMessenger() async {
    final Uri url = Uri.parse(
        'https://www.messenger.com/share?link=${Uri.encodeComponent(videoUrl)}');

    await _launchUrlOrFallback(
        url, 'Check out this First Aid Reel: $videoTitle\n$videoUrl');
  }

  Future<void> _shareToGmail() async {
    final String subject = Uri.encodeComponent(videoTitle);
    final String body = Uri.encodeComponent(
        'Check out this First Aid Reel: $videoTitle\n$videoUrl');
    final Uri gmailUrl =
        Uri.parse('googlegmail://co?subject=$subject&body=$body');
    final Uri emailUrl = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(gmailUrl)) {
      await launchUrl(gmailUrl);
    } else if (await canLaunchUrl(emailUrl)) {
      await launchUrl(emailUrl);
    } else {
      await _shareFallback(
          'Check out this First Aid Reel: $videoTitle\n$videoUrl');
    }
  }

  Future<void> _shareToMessages() async {
    final String body = Uri.encodeComponent(
        'Check out this First Aid Reel: $videoTitle\n$videoUrl');
    final Uri url = Uri.parse('sms:?body=$body');
    await _launchUrlOrFallback(
        url, 'Check out this First Aid Reel: $videoTitle\n$videoUrl');
  }

  Future<void> _shareToFacebook() async {
    // Facebook app doesn't reliably support direct URL sharing; try universal link
    final String link = Uri.encodeComponent(videoUrl);
    final Uri url =
        Uri.parse('https://www.facebook.com/reels/create?link=$link');
    await _launchUrlOrFallback(
        url, 'Check out this First Aid Reel: $videoTitle\n$videoUrl');
  }

  Future<void> _shareToInstagram() async {
    final String link = Uri.encodeComponent(videoUrl);
    final Uri url = Uri.parse('https://www.instagram.com/sharing?link=$link');
    // Instagram app doesn't reliably support direct URL sharing; try universal link
    await _launchUrlOrFallback(
        url, 'Check out this First Aid Reel: $videoTitle\n$videoUrl');
  }

  Future<void> _launchUrlOrFallback(Uri url, String text) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await _shareFallback(text);
    }
  }

  Future<void> _shareFallback(String text) async {
    try {
      await Share.share(
        text,
        subject: videoTitle,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: videoUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Reel',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gilroy',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share to',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Gilroy',
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              _ShareAppButton(
                icon: FontAwesomeIcons.facebook,
                color: const Color(0xFF1877F2),
                label: 'Facebook',
                onTap: _shareToFacebook,
              ),
              _ShareAppButton(
                icon: FontAwesomeIcons.instagram,
                color: const Color(0xFFE1306C),
                label: 'Instagram',
                onTap: _shareToInstagram,
              ),
              _ShareAppButton(
                icon: FontAwesomeIcons.whatsapp,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: _shareToWhatsApp,
              ),
              _ShareAppButton(
                icon: FontAwesomeIcons.facebookMessenger,
                color: const Color(0xFF0084FF),
                label: 'Messenger',
                onTap: _shareToMessenger,
              ),
              _ShareAppButton(
                icon: FontAwesomeIcons.envelope,
                color: const Color(0xFFEA4335),
                label: 'Gmail',
                onTap: _shareToGmail,
              ),
              _ShareAppButton(
                icon: FontAwesomeIcons.message,
                color: const Color(0xFF34C759),
                label: 'Messages',
                onTap: _shareToMessages,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.black),
            title: const Text(
              'Copy Link',
              style: TextStyle(fontFamily: 'Gilroy'),
            ),
            onTap: () => _copyLink(context),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontFamily: 'Gilroy',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareAppButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ShareAppButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Share to $label',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: FaIcon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Gilroy',
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
