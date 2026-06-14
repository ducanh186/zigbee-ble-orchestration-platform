import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import 'automation_visuals.dart';

enum DevicePickerKind { radio, check }

/// Selectable device row used for both the trigger picker (radio) and the
/// target lights picker (check). Shows the device name + the device ID in
/// mono font + the room label.
class DevicePickerRow extends StatelessWidget {
  const DevicePickerRow({
    required this.device,
    required this.selected,
    required this.kind,
    required this.onChanged,
    super.key,
  });

  final SmartDevice device;
  final bool selected;
  final DevicePickerKind kind;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = _typeFor(device);

    return Material(
      color: selected ? palette.primaryTint : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!selected),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? palette.primary
                      : palette.primaryTint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  AutomationVisuals.deviceTypeIcon(type),
                  size: 15,
                  color: selected ? palette.primaryOn : palette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.roomLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Indicator(selected: selected, kind: kind, palette: palette),
            ],
          ),
        ),
      ),
    );
  }

  AutomationDeviceType _typeFor(SmartDevice device) {
    // isEnvironment/isMotion dual-read v2 'sensor'+kind and legacy types.
    if (device.isEnvironment) return AutomationDeviceType.environment;
    if (device.isMotion) return AutomationDeviceType.motion;
    if (device.deviceType == 'switch') return AutomationDeviceType.switchDevice;
    return AutomationDeviceType.light;
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.selected,
    required this.kind,
    required this.palette,
  });

  final bool selected;
  final DevicePickerKind kind;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (kind == DevicePickerKind.check) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.5,
          ),
        ),
        child: selected
            ? Icon(Icons.check, size: 12, color: palette.primaryOn)
            : null,
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.primary : palette.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primary,
              ),
            )
          : null,
    );
  }
}
