import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/event_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';

class LogsView extends StatelessWidget {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Logs'),
              pinned: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
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
                    const AppCard(child: Text('No event log yet.'))
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
  const _LogRow({required this.event, required this.showBorder});

  final EventLog event;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = event.eventType.toLowerCase().contains('error')
        ? Icons.error_outline
        : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(top: BorderSide(color: palette.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
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
                  '${event.eventType} ${event.deviceId ?? ''}'.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(event.message, style: const TextStyle(fontSize: 13)),
                Text(
                  [
                    if (event.source != null) 'source=${event.source}',
                    if (event.commandId != null)
                      'command_id=${event.commandId}',
                  ].join(' - '),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
