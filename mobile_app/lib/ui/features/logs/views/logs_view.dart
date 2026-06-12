import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/event_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/expandable_content.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';

class LogsView extends StatefulWidget {
  const LogsView({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final Set<String> _expandedEventIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(l10n.logsTitle),
              pinned: true,
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      tooltip: l10n.backLabel,
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
              actions: [
                IconButton(
                  tooltip: l10n.refreshTooltip,
                  onPressed: viewModel.load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.list(
                children: [
                  if (viewModel.errorMessage != null) ...[
                    ErrorBanner(
                      message: viewModel.errorMessage!,
                      onRetry: viewModel.load,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (viewModel.events.isEmpty)
                    AppCard(child: Text(l10n.logsNoEvents))
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < viewModel.events.length;
                            index++
                          )
                            _LogRow(
                              event: viewModel.events[index],
                              expanded: _expandedEventIds.contains(
                                viewModel.events[index].id,
                              ),
                              onToggle: () {
                                setState(() {
                                  final eventId = viewModel.events[index].id;
                                  if (_expandedEventIds.contains(eventId)) {
                                    _expandedEventIds.remove(eventId);
                                  } else {
                                    _expandedEventIds.add(eventId);
                                  }
                                });
                              },
                              showBorder: index != 0,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.event,
    required this.expanded,
    required this.onToggle,
    required this.showBorder,
  });

  final EventLog event;
  final bool expanded;
  final VoidCallback onToggle;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final summary = _LogSummary.fromEvent(event);
    final icon = summary.outcome == 'Failed' || summary.outcome == 'Timeout'
        ? Icons.error_outline
        : Icons.check_circle_outline;
    const timestampWidth = 96.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(top: BorderSide(color: palette.border))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: timestampWidth,
                child: Text(
                  event.occurredAt,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(icon, color: palette.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.compactText,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.sourceText,
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
              CollapseIconButton(
                key: Key('log-toggle-${event.id}'),
                expanded: expanded,
                onPressed: onToggle,
              ),
            ],
          ),
          ExpandableBody(
            expanded: expanded,
            child: Padding(
              padding: const EdgeInsets.only(left: timestampWidth + 24, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.rawText,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'type=${event.eventType}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogSummary {
  const _LogSummary({
    required this.outcome,
    required this.subject,
    required this.action,
    required this.detail,
    required this.sourceText,
    required this.rawText,
  });

  final String outcome;
  final String subject;
  final String action;
  final String? detail;
  final String sourceText;
  final String rawText;

  String get compactText =>
      [outcome, subject, action, if (detail != null) detail].join(' - ');

  static _LogSummary fromEvent(EventLog event) {
    final raw = event.message.trim();
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final messageLower = normalized.toLowerCase();
    final combinedLower = '${event.eventType} ${event.source ?? ''} $normalized'
        .toLowerCase();
    final outcome = _outcomeFrom(combinedLower);
    final subject =
        event.deviceId ?? _subjectFrom(event.eventType, combinedLower);
    final actionDetail = _actionDetailFrom(
      event.eventType,
      normalized,
      messageLower,
      combinedLower,
    );
    final source = _displaySource(event.source);

    return _LogSummary(
      outcome: outcome,
      subject: subject,
      action: actionDetail.action,
      detail: actionDetail.detail,
      sourceText: event.commandId == null
          ? source
          : '$source - command_id=${event.commandId}',
      rawText: raw,
    );
  }

  static String _outcomeFrom(String lower) {
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Timeout';
    }
    if (lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('failure')) {
      return 'Failed';
    }
    return 'Success';
  }

  static String _subjectFrom(String eventType, String lower) {
    if (lower.contains('gateway')) {
      return 'home hub';
    }
    final normalizedType = eventType.trim().toLowerCase();
    if (normalizedType.isEmpty || normalizedType == 'event') {
      return 'system';
    }
    return normalizedType.replaceAll('_', ' ');
  }

  static _ActionDetail _actionDetailFrom(
    String eventType,
    String normalized,
    String messageLower,
    String combinedLower,
  ) {
    final colonMatch = RegExp(r'^([^:]+):\s*(.+)$').firstMatch(normalized);

    if (messageLower.startsWith('state reported')) {
      return _ActionDetail('State reported', _truncate(colonMatch?.group(2)));
    }
    if (messageLower.startsWith('command executed')) {
      return _ActionDetail('Command executed', _truncate(colonMatch?.group(2)));
    }
    if (_looksLikeGatewayHealth(eventType, combinedLower)) {
      final entries = _mapEntries(normalized);
      final status =
          entries['status'] ??
          entries['value'] ??
          entries['state'] ??
          entries['network_status'] ??
          entries['network_state'];
      final uptime = entries['uptime_ms'];
      final detailParts = <String>[];

      if (status != null) {
        detailParts.add(status);
      }
      if (uptime != null) {
        detailParts.add('${uptime}ms');
      }
      if (detailParts.isEmpty && entries.isNotEmpty) {
        detailParts.add(
          entries.entries
              .take(2)
              .map((entry) => '${entry.key}=${entry.value}')
              .join(', '),
        );
      }

      return _ActionDetail(
        'Health reported',
        _truncate(detailParts.join(', '), maxLength: 42),
      );
    }
    if (colonMatch != null) {
      return _ActionDetail(
        _titleCasePhrase(colonMatch.group(1)!),
        _truncate(colonMatch.group(2)),
      );
    }

    final entries = _mapEntries(normalized);
    if (entries.isNotEmpty) {
      final preview = entries.entries
          .take(2)
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      return _ActionDetail(
        _humanizeEventType(eventType),
        _truncate(preview, maxLength: 42),
      );
    }

    return _ActionDetail(
      _humanizeEventType(eventType),
      _truncate(normalized, maxLength: 42),
    );
  }

  static bool _looksLikeGatewayHealth(String eventType, String lower) {
    return eventType.toLowerCase().contains('gateway') ||
        lower.contains('gateway_health') ||
        lower.contains('gateway health');
  }

  static String _displaySource(String? source) {
    if (source == null || source.trim().isEmpty) {
      return 'cloud/home hub';
    }
    return source.replaceAll('gateway', 'home hub');
  }

  static Map<String, String> _mapEntries(String message) {
    final matches = RegExp(r'(\w+):\s*([^,}]+)').allMatches(message);
    return {
      for (final match in matches)
        if (match.groupCount >= 2)
          match.group(1)!.toLowerCase(): match.group(2)!.trim(),
    };
  }

  static String _humanizeEventType(String value) {
    final normalized = value.trim().replaceAll('_', ' ');
    if (normalized.isEmpty || normalized.toLowerCase() == 'event') {
      return 'Event recorded';
    }
    return _titleCasePhrase(normalized);
  }

  static String _titleCasePhrase(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  static String? _truncate(String? value, {int maxLength = 24}) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength - 3)}...';
  }
}

class _ActionDetail {
  const _ActionDetail(this.action, this.detail);

  final String action;
  final String? detail;
}
