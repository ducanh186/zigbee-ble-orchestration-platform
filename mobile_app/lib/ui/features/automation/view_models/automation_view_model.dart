import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/services/api_client.dart';
import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/light_scene.dart';
import '../../../../domain/repositories/automation_repository.dart';
import '../../../../domain/repositories/scene_repository.dart';

class AutomationViewModel extends ChangeNotifier {
  AutomationViewModel({
    required AutomationRepository repository,
    SceneRepository? sceneRepository,
    this.pollDelay = const Duration(seconds: 3),
    this.maxPollAttempts = 5,
  }) : _repository = repository,
       _sceneRepository = sceneRepository;

  final AutomationRepository _repository;
  final SceneRepository? _sceneRepository;
  final Duration pollDelay;
  final int maxPollAttempts;

  List<AutomationRule> _rules = [];
  List<LightScene> _scenes = [];
  SceneAvailability _sceneAvailability = SceneAvailability.unavailable;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<LightScene> get scenes => List.unmodifiable(_scenes);
  SceneAvailability get sceneAvailability => _sceneAvailability;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rules = await _repository.fetchRules();
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not load automation rules',
      );
    }

    if (_sceneRepository != null) {
      try {
        _scenes = await _sceneRepository.fetchScenes();
        _sceneAvailability = _sceneRepository.lastAvailability;
      } catch (error) {
        _scenes = [];
        _sceneAvailability = SceneAvailability.unavailable;
        _errorMessage ??= friendlyErrorMessage(
          error,
          context: 'Khong tai duoc scenes',
        );
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createRule(AutomationRuleDraft draft) async {
    if (_isSaving) {
      return;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _repository.createRule(draft);
      _upsert(created);
      notifyListeners();

      if (!created.syncStatus.isFinal) {
        await _pollRule(created.id);
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not create automation rule',
      );
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> enableRule(String ruleId) async {
    await _updateEnabled(ruleId, enabled: true);
  }

  Future<void> disableRule(String ruleId) async {
    await _updateEnabled(ruleId, enabled: false);
  }

  Future<void> deleteRule(String ruleId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteRule(ruleId);
      final refreshedRules = await _repository.fetchRules();
      if (refreshedRules.any((rule) => rule.id == ruleId)) {
        _rules = refreshedRules;
        _errorMessage =
            'Cloud chua xoa rule. Kiem tra backend release hoac API endpoint.';
        return;
      }
      _rules = refreshedRules;
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not delete automation rule',
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> _updateEnabled(String ruleId, {required bool enabled}) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final rule = enabled
          ? await _repository.enableRule(ruleId)
          : await _repository.disableRule(ruleId);
      _upsert(rule);
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not update automation rule',
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> _pollRule(String ruleId) async {
    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      await Future<void>.delayed(pollDelay);
      final rule = await _repository.fetchRule(ruleId);
      _upsert(rule);
      notifyListeners();

      if (rule.syncStatus.isFinal) {
        return;
      }
    }
  }

  void _upsert(AutomationRule rule) {
    final index = _rules.indexWhere((item) => item.id == rule.id);
    if (index == -1) {
      _rules = [rule, ..._rules];
      return;
    }

    final nextRules = List<AutomationRule>.of(_rules);
    nextRules[index] = rule;
    _rules = nextRules;
  }
}
