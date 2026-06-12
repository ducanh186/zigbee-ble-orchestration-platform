import 'package:flutter/material.dart';

import '../../../../domain/models/event_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';

class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({
    required this.events,
    required this.readEventIds,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onBack,
    super.key,
  });

  final List<EventLog> events;
  final Set<String> readEventIds;
  final ValueChanged<String> onMarkRead;
  final VoidCallback onMarkAllRead;
  final VoidCallback onBack;

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  _NotificationCategory _selectedCategory = _NotificationCategory.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = widget.events
        .where((event) => !widget.readEventIds.contains(event.id))
        .length;
    final visibleEvents = widget.events
        .where((event) => _selectedCategory.matches(event))
        .toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(l10n.notificationCenterTitle),
          pinned: true,
          leading: IconButton(
            tooltip: l10n.backLabel,
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            TextButton(
              onPressed: widget.events.isEmpty ? null : widget.onMarkAllRead,
              child: Text(l10n.markAllReadLabel),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    StatusBadge(
                      label: l10n.unreadCount(unreadCount),
                      tone: unreadCount == 0
                          ? BadgeTone.neutral
                          : BadgeTone.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.importantEventsLabel,
                        style: TextStyle(color: context.palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _NotificationCategory.values)
                    ChoiceChip(
                      label: Text(category.localizedLabel(l10n)),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (visibleEvents.isEmpty)
                AppCard(child: Text(l10n.noNotificationsMessage))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var index = 0; index < visibleEvents.length; index++)
                        _NotificationRow(
                          event: visibleEvents[index],
                          read: widget.readEventIds.contains(
                            visibleEvents[index].id,
                          ),
                          showBorder: index != 0,
                          onMarkRead: () =>
                              widget.onMarkRead(visibleEvents[index].id),
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.event,
    required this.read,
    required this.showBorder,
    required this.onMarkRead,
  });

  final EventLog event;
  final bool read;
  final bool showBorder;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final category = _NotificationCategory.fromEvent(event);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(top: BorderSide(color: palette.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            category.icon,
            color: read ? palette.textSecondary : palette.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.eventType,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge(
                      label: category.localizedLabel(l10n),
                      tone: read ? BadgeTone.neutral : BadgeTone.primary,
                      showDot: !read,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  event.occurredAt,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: read ? null : onMarkRead,
            child: Text(l10n.markReadLabel),
          ),
        ],
      ),
    );
  }
}

enum _NotificationCategory {
  all('All', Icons.all_inbox_outlined),
  command('Command', Icons.bolt_outlined),
  automation('Automation', Icons.rule_outlined),
  gateway('Home hub', Icons.router_outlined),
  ota('OTA', Icons.system_update_alt_outlined),
  other('Other', Icons.notifications_outlined);

  const _NotificationCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      _NotificationCategory.all => l10n.notificationCategoryAll,
      _NotificationCategory.command => l10n.notificationCategoryCommand,
      _NotificationCategory.automation => l10n.notificationCategoryAutomation,
      _NotificationCategory.gateway => l10n.notificationCategoryGateway,
      _NotificationCategory.ota => l10n.notificationCategoryOta,
      _NotificationCategory.other => l10n.notificationCategoryOther,
    };
  }

  static _NotificationCategory fromEvent(EventLog event) {
    final text = '${event.eventType} ${event.message} ${event.commandId ?? ''}'
        .toLowerCase();
    if (text.contains('command') || event.commandId != null) {
      return command;
    }
    if (text.contains('automation') || text.contains('occupancy')) {
      return automation;
    }
    if (text.contains('gateway')) {
      return gateway;
    }
    if (text.contains('ota') || text.contains('campaign')) {
      return ota;
    }
    return other;
  }

  bool matches(EventLog event) {
    return this == all || fromEvent(event) == this;
  }
}
