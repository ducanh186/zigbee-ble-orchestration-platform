import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_title.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../view_models/automation_view_model.dart';
import '../widgets/automation_visuals.dart';
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
  const AutomationRulesView({super.key, this.canMutate = true});

  final bool canMutate;

  @override
  State<AutomationRulesView> createState() => _AutomationRulesViewState();
}

class _AutomationRulesViewState extends State<AutomationRulesView> {
  String? _justCreatedRuleId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;

    return Consumer<AutomationViewModel>(
      builder: (context, automation, _) {
        final rules = automation.rules;
        // Resolve trigger/target device ids to their soft labels for display.
        final deviceNames = {
          for (final device
              in context.watch<DeviceDashboardViewModel>().devices)
            device.id: device.name,
        };

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(l10n.automationRulesTitle),
              pinned: true,
              actions: [
                IconButton(
                  tooltip: l10n.refreshTooltip,
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
                child: EmptyRules(
                  onCreate: widget.canMutate ? _openCreate : null,
                ),
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
                    if (widget.canMutate) ...[
                      NewRuleCta(onTap: _openCreate),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: SectionTitle(
                            title: l10n.rulesSectionTitle,
                            action: Text(
                              l10n.ruleCount(rules.length),
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
                          template: AutomationVisuals.templateForRule(rule),
                          deviceNames: deviceNames,
                          highlight: rule.id == _justCreatedRuleId,
                          onEnabledChanged:
                              !widget.canMutate || automation.isSaving
                              ? null
                              : (value) => value
                                    ? automation.enableRule(rule.id)
                                    : automation.disableRule(rule.id),
                          onDelete: widget.canMutate
                              ? () => _confirmDelete(automation, rule)
                              : null,
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

  Future<void> _confirmDelete(
    AutomationViewModel automation,
    AutomationRule rule,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = context.palette;
        return AlertDialog(
          title: Text(l10n.deleteRuleTitle),
          content: Text(l10n.deleteRuleBody(rule.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deleteLabel),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (_justCreatedRuleId == rule.id) {
      setState(() => _justCreatedRuleId = null);
    }
    await automation.deleteRule(rule.id);
  }
}

class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.successTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: palette.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.ruleCreatedMessage,
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
