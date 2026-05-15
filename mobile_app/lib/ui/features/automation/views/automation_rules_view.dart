import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_title.dart';
import '../view_models/automation_view_model.dart';
import '../widgets/create_rule_sheet.dart';
import '../widgets/empty_rules.dart';
import '../widgets/new_rule_cta.dart';
import '../widgets/rule_card.dart';

/// Automation tab — list-first design.
///
/// Rules occupy the screen. Creating a rule opens [CreateRuleSheet]; after
/// a successful save, a green success banner shows and the new rule's card
/// is outlined with the primary color until the next interaction.
class AutomationRulesView extends StatefulWidget {
  const AutomationRulesView({super.key});

  @override
  State<AutomationRulesView> createState() => _AutomationRulesViewState();
}

class _AutomationRulesViewState extends State<AutomationRulesView> {
  String? _justCreatedRuleId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Consumer<AutomationViewModel>(
      builder: (context, automation, _) {
        final rules = automation.rules;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Automation Rules'),
              pinned: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: automation.isLoading ? null : automation.load,
                ),
              ],
            ),
            if (automation.errorMessage != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: automation.errorMessage!,
                    onRetry: automation.load,
                  ),
                ),
              ),
            if (rules.isEmpty && !automation.isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyRules(onCreate: _openCreate),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList.list(
                  children: [
                    if (_justCreatedRuleId != null) ...[
                      _SavedBanner(palette: palette),
                      const SizedBox(height: 12),
                    ],
                    NewRuleCta(onTap: _openCreate),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SectionTitle(
                            title: 'Rules',
                            action: Text(
                              '${rules.length} rule'
                              '${rules.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'JetBrains Mono',
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        if (automation.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final rule in rules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RuleCard(
                          rule: rule,
                          template: _templateFor(rule),
                          highlight: rule.id == _justCreatedRuleId,
                          onEnabledChanged: automation.isSaving
                              ? null
                              : (value) => value
                                    ? automation.enableRule(rule.id)
                                    : automation.disableRule(rule.id),
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

  Future<void> _openCreate() async {
    final ruleId = await CreateRuleSheet.show(context);
    if (!mounted || ruleId == null) {
      return;
    }
    setState(() => _justCreatedRuleId = ruleId);
  }

  /// Best-effort mapping rule → template so the rule card can pick an icon
  /// and a subtitle. Falls back to a switch-based template if the trigger
  /// device type is unknown.
  AutomationRuleTemplate _templateFor(AutomationRule rule) {
    final firstAction = rule.actions.isEmpty
        ? null
        : rule.actions.first.command;
    switch (rule.trigger.event) {
      case AutomationTriggerEvent.occupancyChanged:
        final occupancy = rule.trigger.state['occupancy'];
        if (occupancy == 'unoccupied') {
          return AutomationRuleTemplate.motionUnoccupiedTurnsOffLights;
        }
        return AutomationRuleTemplate.motionOccupiedTurnsOnLights;
      case AutomationTriggerEvent.switchToggle:
        if (rule.actions.length <= 1 ||
            firstAction != AutomationActionCommand.toggle) {
          return AutomationRuleTemplate.switchTogglesOneLight;
        }
        return AutomationRuleTemplate.switchTogglesLights;
    }
  }
}

class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.successTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: palette.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rule created. Waiting for gateway sync.',
              style: TextStyle(
                color: palette.success,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
