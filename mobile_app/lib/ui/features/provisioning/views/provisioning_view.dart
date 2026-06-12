import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/provisioning_session.dart';
import '../../../../domain/repositories/provisioning_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/localized_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';

typedef ProvisioningQrScanLauncher =
    Future<String?> Function(BuildContext context);

Future<String?> _defaultProvisioningQrScanLauncher(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _ProvisioningQrScannerPage()),
  );
}

class ProvisioningView extends StatefulWidget {
  const ProvisioningView({
    this.initialPayload,
    this.qrScanLauncher = _defaultProvisioningQrScanLauncher,
    this.pollInterval = const Duration(seconds: 2),
    super.key,
  });

  final ProvisioningQrPayload? initialPayload;
  final ProvisioningQrScanLauncher qrScanLauncher;
  final Duration pollInterval;

  @override
  State<ProvisioningView> createState() => _ProvisioningViewState();
}

class _ProvisioningViewState extends State<ProvisioningView> {
  static const String _defaultJoinTargetId = 'gw-ubuntu-01';

  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _manualQrController = TextEditingController();
  StreamSubscription<ProvisioningSession>? _polling;
  ProvisioningQrPayload? _payload;
  ProvisioningSession? _session;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _payload = widget.initialPayload;
  }

  @override
  void dispose() {
    _polling?.cancel();
    _roomController.dispose();
    _manualQrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final payload = _payload;
    final session = _session;

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: Text(l10n.provisioningTab), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              SectionTitle(title: l10n.provisioningWizardTitle),
              const SizedBox(height: 8),
              _SessionStatusCard(
                session: session,
                error: _error == null
                    ? null
                    : localizedErrorMessage(l10n, _error!),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: TextField(
                  key: const Key('provisioning-room-field'),
                  controller: _roomController,
                  decoration: InputDecoration(
                    labelText: l10n.roomIdLabel,
                    prefixIcon: const Icon(Icons.meeting_room_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('provisioning-scan-button'),
                            onPressed: _scanQr,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(l10n.scanQrLabel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('provisioning-apply-manual-button'),
                            onPressed: _applyManualQr,
                            icon: const Icon(Icons.input),
                            label: Text(l10n.useManualLabel),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('provisioning-manual-qr-field'),
                      controller: _manualQrController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.qrJsonLabel,
                        prefixIcon: const Icon(Icons.data_object),
                      ),
                    ),
                    if (payload != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const Key('provisioning-clear-payload-button'),
                          onPressed: _clearPayload,
                          icon: const Icon(Icons.clear),
                          label: Text(l10n.clearLabel),
                        ),
                      ),
                    ],
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
                    label: Text(l10n.startProvisioningLabel),
                  ),
                  if (session != null && !session.isTerminal) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('provisioning-cancel-button'),
                      onPressed: _cancelProvisioning,
                      icon: const Icon(Icons.close),
                      label: Text(l10n.cancelLabel),
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
    final session = _session;
    return _payload != null &&
        !_isSubmitting &&
        (session == null ||
            (session.isTerminal &&
                session.status != ProvisioningStatus.joined)) &&
        _roomController.text.trim().isNotEmpty;
  }

  Future<void> _startProvisioning() async {
    final payload = _payload;
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
        gatewayId: _defaultJoinTargetId,
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

  Future<void> _scanQr() async {
    final rawPayload = await widget.qrScanLauncher(context);
    if (!mounted || rawPayload == null || rawPayload.trim().isEmpty) {
      return;
    }
    _manualQrController.text = rawPayload;
    _applyRawPayload(rawPayload);
  }

  void _applyManualQr() {
    final rawPayload = _manualQrController.text;
    if (rawPayload.trim().isEmpty) {
      setState(() {
        _payload = null;
        _session = null;
        _error = null;
      });
      return;
    }
    _applyRawPayload(rawPayload);
  }

  void _applyRawPayload(String rawPayload) {
    try {
      final payload = ProvisioningQrPayload.parseJson(rawPayload);
      setState(() {
        _payload = payload;
        _session = null;
        _error = null;
      });
    } on FormatException {
      setState(() {
        _payload = null;
        _session = null;
        _error = validationErrorMessage;
      });
    } catch (error) {
      setState(() {
        _payload = null;
        _session = null;
        _error = error.toString();
      });
    }
  }

  void _clearPayload() {
    _manualQrController.clear();
    setState(() {
      _payload = null;
      _session = null;
      _error = null;
    });
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

class _ProvisioningQrScannerPage extends StatefulWidget {
  const _ProvisioningQrScannerPage();

  @override
  State<_ProvisioningQrScannerPage> createState() =>
      _ProvisioningQrScannerPageState();
}

class _ProvisioningQrScannerPageState
    extends State<_ProvisioningQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handledResult = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanProvisioningQrTitle)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handledResult || capture.barcodes.isEmpty) {
      return;
    }
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    _handledResult = true;
    unawaited(_controller.stop());
    Navigator.of(context).pop(rawValue);
  }
}

class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({required this.session, required this.error});

  final ProvisioningSession? session;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
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
                  _statusCopy(status, session?.reason, l10n),
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

  String _statusCopy(
    ProvisioningStatus? status,
    String? reason,
    AppLocalizations l10n,
  ) {
    return switch (status) {
      ProvisioningStatus.pending => l10n.provisioningSessionCreated,
      ProvisioningStatus.permitOpen => l10n.provisioningPermitOpen,
      ProvisioningStatus.joining => l10n.provisioningJoining,
      ProvisioningStatus.joined => l10n.provisioningJoined,
      ProvisioningStatus.failed => reason ?? l10n.provisioningFailed,
      ProvisioningStatus.expired => l10n.provisioningExpired,
      ProvisioningStatus.cancelled => l10n.provisioningCancelled,
      null => l10n.provisioningReady,
    };
  }
}

class _DeviceIdentityCard extends StatelessWidget {
  const _DeviceIdentityCard({required this.payload});

  final ProvisioningQrPayload? payload;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      child: payload == null
          ? Row(
              children: [
                Icon(Icons.qr_code_scanner, color: palette.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.deviceIdentityRequired,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deviceIdentityTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _IdentityRow(label: 'EUI64', value: payload!.eui64),
                _IdentityRow(
                  label: l10n.deviceTypeLabel,
                  value: payload!.deviceType.wireValue,
                ),
                if (payload!.model != null)
                  _IdentityRow(label: l10n.modelLabel, value: payload!.model!),
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
