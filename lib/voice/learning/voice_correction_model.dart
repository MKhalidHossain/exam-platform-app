import '../core/voice_command_context.dart';
import '../core/voice_intent.dart';

class VoiceCorrectionModel {
  final String rawHeardText;
  final String normalizedText;
  final VoiceIntentType intentType;
  final String? value;
  final int? number;
  final VoiceScreenContext screenContext;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int useCount;
  final bool isRisky;

  const VoiceCorrectionModel({
    required this.rawHeardText,
    required this.normalizedText,
    required this.intentType,
    this.value,
    this.number,
    required this.screenContext,
    required this.createdAt,
    required this.lastUsedAt,
    required this.useCount,
    required this.isRisky,
  });

  VoiceCorrectionModel copyWith({
    String? rawHeardText,
    String? normalizedText,
    VoiceIntentType? intentType,
    String? value,
    int? number,
    VoiceScreenContext? screenContext,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? useCount,
    bool? isRisky,
  }) {
    return VoiceCorrectionModel(
      rawHeardText: rawHeardText ?? this.rawHeardText,
      normalizedText: normalizedText ?? this.normalizedText,
      intentType: intentType ?? this.intentType,
      value: value ?? this.value,
      number: number ?? this.number,
      screenContext: screenContext ?? this.screenContext,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
      isRisky: isRisky ?? this.isRisky,
    );
  }

  VoiceIntent toIntent({
    required String rawText,
    required String normalizedText,
    double confidence = 0.95,
  }) {
    return VoiceIntent(
      type: intentType,
      value: value,
      number: number,
      confidence: confidence,
      isRisky: isRisky,
      rawText: rawText,
      normalizedText: normalizedText,
      source: 'learned_correction',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawHeardText': rawHeardText,
      'normalizedText': normalizedText,
      'intentType': intentType.name,
      'value': value,
      'number': number,
      'screenContext': screenContext.name,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'useCount': useCount,
      'isRisky': isRisky,
    };
  }

  static VoiceCorrectionModel? fromJson(Map<String, dynamic> json) {
    final rawHeardText = json['rawHeardText'];
    final normalizedText = json['normalizedText'];
    final intentTypeName = json['intentType'];
    final screenContextName = json['screenContext'];
    final createdAtText = json['createdAt'];
    final lastUsedAtText = json['lastUsedAt'];
    final useCount = json['useCount'];
    final isRisky = json['isRisky'];

    if (rawHeardText is! String ||
        normalizedText is! String ||
        intentTypeName is! String ||
        screenContextName is! String ||
        createdAtText is! String ||
        lastUsedAtText is! String ||
        useCount is! int ||
        isRisky is! bool ||
        rawHeardText.trim().isEmpty ||
        normalizedText.trim().isEmpty) {
      return null;
    }

    final intentType = _intentTypeFromName(intentTypeName);
    final screenContext = _screenContextFromName(screenContextName);
    final createdAt = DateTime.tryParse(createdAtText);
    final lastUsedAt = DateTime.tryParse(lastUsedAtText);
    if (intentType == null ||
        screenContext == null ||
        createdAt == null ||
        lastUsedAt == null) {
      return null;
    }

    final value = json['value'];
    final number = json['number'];
    return VoiceCorrectionModel(
      rawHeardText: rawHeardText,
      normalizedText: normalizedText,
      intentType: intentType,
      value: value is String ? value : null,
      number: number is int ? number : null,
      screenContext: screenContext,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
      useCount: useCount,
      isRisky: isRisky,
    );
  }

  static VoiceIntentType? _intentTypeFromName(String name) {
    for (final type in VoiceIntentType.values) {
      if (type.name == name) return type;
    }
    return null;
  }

  static VoiceScreenContext? _screenContextFromName(String name) {
    for (final context in VoiceScreenContext.values) {
      if (context.name == name) return context;
    }
    return null;
  }
}
