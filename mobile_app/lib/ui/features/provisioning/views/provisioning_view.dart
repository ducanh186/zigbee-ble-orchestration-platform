import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';

class ProvisioningView extends StatelessWidget {
  const ProvisioningView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: Text(l10n.provisioningTab), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.hub, color: palette.primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provisioning placeholder',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Device pairing flow will be added after gateway provisioning API exists.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Expected flow'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: const [
                    _ProvisioningStep(
                      icon: Icons.qr_code_scanner,
                      title: 'Scan node identity',
                      subtitle: 'Read QR or EUI64 from the device label.',
                    ),
                    SizedBox(height: 12),
                    _ProvisioningStep(
                      icon: Icons.wifi_tethering,
                      title: 'Permit join',
                      subtitle: 'Open a short join window on the gateway.',
                    ),
                    SizedBox(height: 12),
                    _ProvisioningStep(
                      icon: Icons.meeting_room_outlined,
                      title: 'Assign room',
                      subtitle: 'Name the node and place it in a room.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProvisioningStep extends StatelessWidget {
  const _ProvisioningStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
