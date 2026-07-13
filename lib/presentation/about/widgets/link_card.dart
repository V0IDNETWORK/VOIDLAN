import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// One row in the About screen's link list: platform icon, label, and
/// open/copy/share actions for a single URL or email address.
class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.index = 0,
  });

  final IconData icon;
  final String label;
  final String value;
  final int index;

  bool get _isEmail => value.startsWith('mailto:');

  Future<void> _open() async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copy(BuildContext context) async {
    final text = _isEmail ? value.replaceFirst('mailto:', '') : value;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied $label'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _share() async {
    final text = _isEmail ? value.replaceFirst('mailto:', '') : value;
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.14),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      _isEmail ? value.replaceFirst('mailto:', '') : value,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () => _copy(context),
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined, size: 18),
                onPressed: _share,
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 260.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.12, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
  }
}
