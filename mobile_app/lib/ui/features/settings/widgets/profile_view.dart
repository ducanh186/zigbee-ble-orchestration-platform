import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/expandable_content.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({required this.onBack, this.onLogout, super.key});

  final VoidCallback onBack;
  final VoidCallback? onLogout;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _sessionExpanded = true;
  bool _actionsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(l10n.profileTitle),
          pinned: true,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: l10n.settingsTab,
              onPressed: widget.onBack,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'NT',
                        style: TextStyle(
                          color: palette.primaryOn,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nguyen Tri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'tech.operator',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusBadge(
                            label: l10n.profileRoleTech,
                            tone: BadgeTone.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                title: l10n.profileSession,
                action: CollapseIconButton(
                  key: const Key('profile-session-toggle'),
                  expanded: _sessionExpanded,
                  onPressed: () {
                    setState(() => _sessionExpanded = !_sessionExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _sessionExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _ProfileRow(
                            icon: Icons.business_outlined,
                            label: l10n.profileOrganization,
                            value: 'HUST - IoT Lab',
                          ),
                          Divider(color: palette.border, height: 1),
                          _ProfileRow(
                            icon: Icons.access_time,
                            label: l10n.profileSignedIn,
                            value: '07:01 05/16/2026',
                            mono: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _ProfileRow(
                            icon: Icons.public,
                            label: l10n.profileApiEndpoint,
                            value: 'http://98.83.4.87:8000',
                            mono: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _ProfileRow(
                            icon: Icons.router_outlined,
                            label: l10n.profileGateway,
                            value: 'z3gw-01 - online',
                            mono: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionTitle(
                title: l10n.profileActions,
                action: CollapseIconButton(
                  key: const Key('profile-actions-toggle'),
                  expanded: _actionsExpanded,
                  onPressed: () {
                    setState(() => _actionsExpanded = !_actionsExpanded);
                  },
                ),
              ),
              ExpandableBody(
                expanded: _actionsExpanded,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _ProfileRow(
                            icon: Icons.key_outlined,
                            label: '...',
                            value: l10n.profileChangePassword,
                            actionable: true,
                          ),
                          Divider(color: palette.border, height: 1),
                          _ProfileRow(
                            icon: Icons.copy_outlined,
                            label: 'API',
                            value: l10n.profileCopyToken,
                            actionable: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppCard(
                onTap: widget.onLogout,
                child: Row(
                  children: [
                    Icon(Icons.logout, color: palette.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.profileSignOut,
                        style: TextStyle(
                          color: palette.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.actionable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final bool actionable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: palette.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: mono ? 'JetBrains Mono' : null,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionable)
            Icon(Icons.chevron_right, color: palette.textSecondary),
        ],
      ),
    );
  }
}
