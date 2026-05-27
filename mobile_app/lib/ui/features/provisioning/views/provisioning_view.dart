import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/provisioning_session.dart';
import '../../../../domain/repositories/provisioning_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';

class ProvisioningView extends StatefulWidget {
  const ProvisioningView({
    this.initialPayload,
    this.pollInterval = const Duration(seconds: 2),
    super.key,
  });

  final ProvisioningQrPayload? initialPayload;
  final Duration pollInterval;

  @override
  State<ProvisioningView> createState() => _ProvisioningViewState();
}

class _ProvisioningViewState extends State<ProvisioningView> {
  final TextEditingController _gatewayController = TextEditingController(
    text: 'gw-ubuntu-01',
  );
  final TextEditingController _roomController = TextEditingController();
  StreamSubscription<ProvisioningSession>? _polling;
  ProvisioningSession? _session;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _polling?.cancel();
    _gatewayController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)?.provisioningTab ?? 'Provisioning';
    final payload = widget.initialPayload;
    final session = _session;

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: Text(title), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              const SectionTitle(title: 'Provisioning wizard'),
              const SizedBox(height: 8),
              _SessionStatusCard(session: session, error: _error),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('provisioning-gateway-field'),
                      controller: _gatewayController,
                      decoration: const InputDecoration(
                        labelText: 'Gateway ID',
                        prefixIcon: Icon(Icons.hub_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('provisioning-room-field'),
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room ID',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DeviceIdentityCard(payload: payload),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('provisioning-start-button'),
                    onPressed: _canStart ? _startProvisioning : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Start provisioning'),
                  ),
                  if (session != null && !session.isTerminal) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('provisioning-cancel-button'),
                      onPressed: _cancelProvisioning,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _canStart {
    return widget.initialPayload != null &&
        !_isSubmitting &&
        (_session == null || _session!.isTerminal) &&
        _gatewayController.text.trim().isNotEmpty &&
        _roomController.text.trim().isNotEmpty;
  }

  Future<void> _startProvisioning() async {
    final payload = widget.initialPayload;
    if (payload == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repository = context.read<ProvisioningRepository>();
      final session = await repository.createSession(
        gatewayId: _gatewayController.text.trim(),
        roomId: _roomController.text.trim(),
        payload: payload,
      );
      setState(() => _session = session);
      _polling?.cancel();
      _polling = repository
          .pollSession(session.sessionId, interval: widget.pollInterval)
          .listen(
            (nextSession) {
              if (mounted) {
                setState(() => _session = nextSession);
              }
            },
            onError: (Object error) {
              if (mounted) {
                setState(() => _error = error.toString());
              }
            },
          );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _cancelProvisioning() async {
    final session = _session;
    if (session == null || session.isTerminal) {
      return;
    }

    setState(() => _error = null);
    try {
      _polling?.cancel();
      _polling = null;
      final nextSession = await context
          .read<ProvisioningRepository>()
          .cancelSession(session.sessionId);
      setState(() => _session = nextSession);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({required this.session, required this.error});

  final ProvisioningSession? session;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = session?.status;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(status), color: palette.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(status),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusCopy(status, session?.reason),
                  style: TextStyle(color: palette.textSecondary),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: palette.error)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(ProvisioningStatus? status) {
    return switch (status) {
      ProvisioningStatus.joined => Icons.check_circle_outline,
      ProvisioningStatus.failed ||
      ProvisioningStatus.expired ||
      ProvisioningStatus.cancelled => Icons.error_outline,
      ProvisioningStatus.pending ||
      ProvisioningStatus.permitOpen ||
      ProvisioningStatus.joining => Icons.wifi_tethering,
      null => Icons.qr_code_2,
    };
  }

  String _statusLabel(ProvisioningStatus? status) {
    return switch (status) {
      ProvisioningStatus.pending => 'PENDING',
      ProvisioningStatus.permitOpen => 'PERMIT OPEN',
      ProvisioningStatus.joining => 'JOINING',
      ProvisioningStatus.joined => 'JOINED',
      ProvisioningStatus.failed => 'FAILED',
      ProvisioningStatus.expired => 'EXPIRED',
      ProvisioningStatus.cancelled => 'CANCELLED',
      null => 'READY',
    };
  }

  String _statusCopy(ProvisioningStatus? status, String? reason) {
    return switch (status) {
      ProvisioningStatus.pending => 'Session created in Cloud.',
      ProvisioningStatus.permitOpen => 'Gateway is accepting this device.',
      ProvisioningStatus.joining => 'Device is joining the Zigbee network.',
      ProvisioningStatus.joined => 'Device joined and is ready for room use.',
      ProvisioningStatus.failed => reason ?? 'Provisioning failed.',
      ProvisioningStatus.expired => 'Provisioning session expired.',
      ProvisioningStatus.cancelled => 'Provisioning session cancelled.',
      null => 'Enter gateway, room, and device identity.',
    };
  }
}

class _DeviceIdentityCard extends StatelessWidget {
  const _DeviceIdentityCard({required this.payload});

  final ProvisioningQrPayload? payload;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: payload == null
          ? Row(
              children: [
                Icon(Icons.qr_code_scanner, color: palette.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Device identity required',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device identity',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _IdentityRow(label: 'EUI64', value: payload!.eui64),
                _IdentityRow(
                  label: 'Type',
                  value: payload!.deviceType.wireValue,
                ),
                if (payload!.model != null)
                  _IdentityRow(label: 'Model', value: payload!.model!),
              ],
            ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(color: palette.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
