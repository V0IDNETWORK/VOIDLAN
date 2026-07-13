import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/device_model.dart';

/// A single row in the LAN Explorer device list showing status, name,
/// IP, and ping — tapping opens [DeviceDetailsScreen].
class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onTap});

  final DeviceModel device;
  final VoidCallback onTap;

  IconData get _typeIcon {
    switch (device.deviceType) {
      case DeviceType.desktop:
        return Icons.desktop_windows_outlined;
      case DeviceType.mobile:
        return Icons.smartphone_outlined;
      case DeviceType.server:
        return Icons.dns_outlined;
      case DeviceType.router:
        return Icons.router_outlined;
      case DeviceType.unknown:
        return Icons.device_unknown_outlined;
    }
  }

  Color get _statusColor {
    switch (device.status) {
      case DeviceStatus.online:
        return AppColors.statusOnline;
      case DeviceStatus.offline:
        return AppColors.statusOffline;
      case DeviceStatus.pairing:
        return AppColors.statusPending;
      case DeviceStatus.paired:
        return AppColors.voidCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.14),
                    child: Icon(_typeIcon, color: theme.colorScheme.primary),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                    )
                        .animate(
                          onPlay: (controller) => device.status == DeviceStatus.online
                              ? controller.repeat(reverse: true)
                              : null,
                        )
                        .scaleXY(
                          begin: 1,
                          end: device.status == DeviceStatus.online ? 1.3 : 1,
                          duration: 900.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(device.ipAddress,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  ],
                ),
              ),
              if (device.isVoidLanPeer)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.verified, size: 18, color: AppColors.voidCyan),
                ),
              if (device.pingMs != null)
                Text('${device.pingMs} ms',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.04, end: 0, duration: 220.ms);
  }
}
