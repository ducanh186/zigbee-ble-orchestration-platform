import 'package:flutter/material.dart';

import '../../../../domain/models/light_scene.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../domain/repositories/scene_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

sealed class ScheduleTargetSelection {
  const ScheduleTargetSelection();
}

final class DirectLightTarget extends ScheduleTargetSelection {
  const DirectLightTarget(this.deviceId);

  final String deviceId;
}

final class SceneTarget extends ScheduleTargetSelection {
  const SceneTarget(this.groupId, this.sceneId);

  final String groupId;
  final String sceneId;
}

enum _TargetMode { directLight, scene }

class SceneTargetSection extends StatefulWidget {
  const SceneTargetSection({
    required this.availability,
    required this.lights,
    required this.scenes,
    required this.onChanged,
    super.key,
  });

  final SceneAvailability availability;
  final List<SmartDevice> lights;
  final List<LightScene> scenes;
  final ValueChanged<ScheduleTargetSelection?> onChanged;

  @override
  State<SceneTargetSection> createState() => _SceneTargetSectionState();
}

class _SceneTargetSectionState extends State<SceneTargetSection> {
  _TargetMode _mode = _TargetMode.directLight;
  String? _selectedLightId;
  SceneTarget? _selectedScene;

  bool get _hasScenes =>
      widget.availability == SceneAvailability.available &&
      widget.scenes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleLights = widget.lights
        .where((device) => device.isLight)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.directLightLabel),
              selected: _mode == _TargetMode.directLight,
              onSelected: (_) => _setMode(_TargetMode.directLight),
            ),
            ChoiceChip(
              label: Text(l10n.sceneLabel),
              selected: _mode == _TargetMode.scene,
              onSelected: _hasScenes
                  ? (_) => _setMode(_TargetMode.scene)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!_hasScenes)
          Text(
            l10n.noScenesAvailable,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (!_hasScenes) const SizedBox(height: 10),
        if (_mode == _TargetMode.directLight)
          for (final light in visibleLights)
            _TargetCard(
              label: light.name,
              selected: _selectedLightId == light.id,
              onTap: () => _selectLight(light.id),
            )
        else
          for (final scene in widget.scenes)
            _TargetCard(
              label: scene.label,
              selected:
                  _selectedScene?.groupId == scene.groupId &&
                  _selectedScene?.sceneId == scene.sceneId,
              onTap: () => _selectScene(scene),
            ),
      ],
    );
  }

  void _setMode(_TargetMode mode) {
    if (_mode == mode || (mode == _TargetMode.scene && !_hasScenes)) {
      return;
    }
    setState(() {
      _mode = mode;
      _selectedLightId = null;
      _selectedScene = null;
    });
    widget.onChanged(null);
  }

  void _selectLight(String deviceId) {
    setState(() {
      _selectedLightId = deviceId;
    });
    widget.onChanged(DirectLightTarget(deviceId));
  }

  void _selectScene(LightScene scene) {
    final target = SceneTarget(scene.groupId, scene.sceneId);
    setState(() {
      _selectedScene = target;
    });
    widget.onChanged(target);
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? palette.primaryTint : palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: palette.primary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
