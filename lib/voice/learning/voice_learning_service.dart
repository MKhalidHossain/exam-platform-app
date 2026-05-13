import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/voice_command_context.dart';
import '../core/voice_intent.dart';
import '../core/voice_safety_policy.dart';
import '../parsing/voice_text_normalizer.dart';
import 'voice_correction_model.dart';

class VoiceLearningService {
  static const int maxCorrections = 200;
  static const String baseStorageKey = 'voice_learning_corrections';

  final String userOrDeviceId;

  const VoiceLearningService({this.userOrDeviceId = 'device'});

  String get storageKey => '${baseStorageKey}_$userOrDeviceId';

  Future<List<VoiceCorrectionModel>> getCorrections(
    VoiceScreenContext context,
  ) async {
    final corrections = await _readCorrections();
    return corrections
        .where((correction) => correction.screenContext == context)
        .toList(growable: false);
  }

  Future<VoiceCorrectionModel?> findCorrection(
    String rawText,
    VoiceScreenContext context,
  ) async {
    final normalizedText = VoiceTextNormalizer.normalize(rawText);
    if (normalizedText.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final corrections = await _readCorrectionsFromPrefs(prefs);
    for (final correction in corrections) {
      if (correction.screenContext != context ||
          correction.normalizedText != normalizedText) {
        continue;
      }

      final updated = correction.copyWith(
        lastUsedAt: DateTime.now(),
        useCount: correction.useCount + 1,
      );
      final updatedCorrections = [
        updated,
        ...corrections.where((entry) => !_isSameCorrection(entry, correction)),
      ];
      await _writeCorrections(prefs, updatedCorrections);
      return updated;
    }

    return null;
  }

  Future<bool> saveCorrection({
    required String rawHeardText,
    required VoiceIntent intent,
    required VoiceScreenContext screenContext,
    required bool userConfirmed,
    DateTime? now,
  }) async {
    if (!userConfirmed) return false;
    if (VoiceSafetyPolicy.isRiskyIntent(intent)) return false;

    final normalizedText = VoiceTextNormalizer.normalize(rawHeardText);
    if (normalizedText.isEmpty) return false;

    final isRisky =
        intent.isRisky ||
        VoiceSafetyPolicy.isRiskyIntentType(intent.type) ||
        VoiceSafetyPolicy.isRiskyText(normalizedText);
    if (isRisky) return false;

    final timestamp = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final corrections = await _readCorrectionsFromPrefs(prefs);
    final existing = corrections.where(
      (entry) =>
          entry.screenContext == screenContext &&
          entry.normalizedText == normalizedText,
    );
    final existingCorrection = existing.isEmpty ? null : existing.first;

    final correction = VoiceCorrectionModel(
      rawHeardText: rawHeardText,
      normalizedText: normalizedText,
      intentType: intent.type,
      value: intent.value,
      number: intent.number,
      screenContext: screenContext,
      createdAt: existingCorrection?.createdAt ?? timestamp,
      lastUsedAt: timestamp,
      useCount: existingCorrection?.useCount ?? 0,
      isRisky: false,
    );

    final nextCorrections = [
      correction,
      ...corrections.where((entry) => !_isSameCorrection(entry, correction)),
    ].take(maxCorrections).toList(growable: false);

    await _writeCorrections(prefs, nextCorrections);
    return true;
  }

  Future<void> clearCorrections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Future<List<VoiceCorrectionModel>> _readCorrections() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCorrectionsFromPrefs(prefs);
  }

  Future<List<VoiceCorrectionModel>> _readCorrectionsFromPrefs(
    SharedPreferences prefs,
  ) async {
    final stored = prefs.getStringList(storageKey) ?? const <String>[];
    final corrections = <VoiceCorrectionModel>[];
    for (final rawEntry in stored) {
      try {
        final decoded = jsonDecode(rawEntry);
        if (decoded is! Map<String, dynamic>) continue;
        final correction = VoiceCorrectionModel.fromJson(decoded);
        if (correction == null || correction.isRisky) continue;
        corrections.add(correction);
      } catch (_) {
        continue;
      }
    }
    return corrections;
  }

  Future<void> _writeCorrections(
    SharedPreferences prefs,
    List<VoiceCorrectionModel> corrections,
  ) async {
    final capped = corrections.take(maxCorrections).toList(growable: false);
    await prefs.setStringList(
      storageKey,
      capped.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  bool _isSameCorrection(
    VoiceCorrectionModel first,
    VoiceCorrectionModel second,
  ) {
    return first.screenContext == second.screenContext &&
        first.normalizedText == second.normalizedText;
  }
}
