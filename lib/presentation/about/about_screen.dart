import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'widgets/link_card.dart';

class _LinkEntry {
  const _LinkEntry(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

const _links = [
  _LinkEntry(Icons.language, 'Website', 'https://voidnetwork.ir'),
  _LinkEntry(Icons.code, 'GitHub', 'https://github.com/V0IDNETWORK'),
  _LinkEntry(Icons.business_center_outlined, 'LinkedIn', 'https://linkedin.com/in/ilianothing'),
  _LinkEntry(Icons.inventory_2_outlined, 'PyPI', 'https://pypi.org/user/ilianothing/'),
  _LinkEntry(Icons.school_outlined, 'TryHackMe', 'https://tryhackme.com/p/ilianothingg'),
  _LinkEntry(Icons.article_outlined, 'Medium', 'https://medium.com/@ilianothingg'),
  _LinkEntry(Icons.play_circle_outline, 'YouTube', 'https://youtube.com/@locailife'),
  _LinkEntry(Icons.camera_alt_outlined, 'Instagram', 'https://instagram.com/ilianothing'),
  _LinkEntry(Icons.send_outlined, 'Telegram', 'https://t.me/voidxMaster'),
  _LinkEntry(Icons.face_outlined, 'Gravatar', 'https://gravatar.com/profound851a01b866'),
  _LinkEntry(Icons.storefront_outlined, 'Myket', 'https://myket.ir/developer/dev-97436'),
  _LinkEntry(Icons.email_outlined, 'Email', 'mailto:ilianothingg@gmail.com'),
];

/// Tab 2 — project and developer profile page.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hub_outlined, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('V0IDNETWORK',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'V0IDNETWORK is an ongoing, open research effort to document '
                'rigorously and accurately how modern Internet circumvention and '
                'surveillance technologies work at the protocol level in support '
                'of a more open and resilient Internet.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Links', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (var i = 0; i < _links.length; i++) ...[
            LinkCard(
              icon: _links[i].icon,
              label: _links[i].label,
              value: _links[i].value,
              index: i,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Center(
            child: Text('VOID LAN — offline LAN companion app',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }
}
