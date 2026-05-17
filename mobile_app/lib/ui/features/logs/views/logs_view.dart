import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/event_log.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../widgets/notification_event_tile.dart';

/// Mobile notification center.
///
/// Renders the cloud event stream as a newest-first list of
/// [NotificationEventTile]s. Sorting is done client-side by the
/// `occurred_at` string from the cloud (a `HH:mm MM/dd/YYYY` display
/// format), which is monotonic enough for ordering even without parsing,
/// because the cloud also returns events DESC from `/api/events`. The
/// explicit sort here is defensive against test fixtures or repository
/// implementations that don't preserve that order.
class LogsView extends StatelessWidget {
  const LogsView({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDashboardViewModel>(
      builder: (context, viewModel, _) {
        final events = _newestFirst(viewModel.events);
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Logs'),
              pinned: true,
              leading: onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
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
                  if (events.isEmpty)
                    const AppCard(child: Text('No event log yet.'))
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var index = 0; index < events.length; index++)
                            NotificationEventTile(
                              event: events[index],
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

  /// Returns [events] sorted newest-first.
  ///
  /// The cloud emits `occurred_at` as a display string `HH:mm MM/dd/YYYY` (see
  /// `TS_DISPLAY_FORMAT` in `cloud/app/schemas.py`). Lexical sort on that
  /// string is wrong across dates, so the comparator parses each timestamp
  /// into a `DateTime`. Unparseable strings fall back to the raw string sort
  /// so the test fixture order remains predictable even with synthetic data.
  List<EventLog> _newestFirst(List<EventLog> events) {
    final sorted = List<EventLog>.of(events);
    sorted.sort((a, b) {
      final aDate = _parseOccurredAt(a.occurredAt);
      final bDate = _parseOccurredAt(b.occurredAt);
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      return b.occurredAt.compareTo(a.occurredAt);
    });
    return sorted;
  }

  /// Parses `HH:mm MM/dd/YYYY` (cloud display format) into a `DateTime`.
  /// Returns `null` when the input doesn't match so the caller can fall back
  /// to lexical comparison.
  DateTime? _parseOccurredAt(String value) {
    if (value.isEmpty) return null;
    // Also accept ISO-8601 in case other code paths inject it.
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final parts = value.split(' ');
    if (parts.length != 2) return null;
    final time = parts[0].split(':');
    final date = parts[1].split('/');
    if (time.length != 2 || date.length != 3) return null;
    final hour = int.tryParse(time[0]);
    final minute = int.tryParse(time[1]);
    final month = int.tryParse(date[0]);
    final day = int.tryParse(date[1]);
    final year = int.tryParse(date[2]);
    if (hour == null ||
        minute == null ||
        month == null ||
        day == null ||
        year == null) {
      return null;
    }
    return DateTime(year, month, day, hour, minute);
  }
}
