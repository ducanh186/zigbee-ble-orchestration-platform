import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app_runtime_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final runtime = context.watch<AppRuntimeConfig>();
    final themeController = context.watch<ThemeController>();
    final palette = context.palette;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Settings'), pinned: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              const SectionTitle(title: 'Theme mode'),
              const SizedBox(height: 8),
              AppCard(
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.grey,
                        icon: Icon(Icons.tonality_outlined),
                        label: Text('Grey'),
                      ),
                    ],
                    selected: {themeController.mode},
                    onSelectionChanged: (selection) {
                      themeController.setMode(selection.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Runtime'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingLine(
                      label: 'Data source',
                      value: runtime.useMockApi ? 'Mock API' : 'Cloud API',
                    ),
                    const SizedBox(height: 12),
                    _SettingLine(
                      label: 'API_BASE_URL',
                      value: runtime.apiBaseUrl,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Run remote mode with --dart-define=USE_MOCK_API=false and --dart-define=API_BASE_URL=<cloud-host>.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.45,
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

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
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
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
        ),
      ],
    );
  }
}
