import '../models/automation_rule.dart';

abstract class AutomationRepository {
  Future<List<AutomationRule>> fetchRules();

  Future<AutomationRule> fetchRule(String ruleId);

  Future<AutomationRule> createRule(AutomationRuleDraft draft);

  Future<AutomationRule> enableRule(String ruleId);

  Future<AutomationRule> disableRule(String ruleId);
}
