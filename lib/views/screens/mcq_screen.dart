import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:get/get.dart';
import '../../controllers/quiz_voice_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../utils/voice_command_processor.dart';
import '../../utils/quiz_voice_intent_parser.dart';
import '../../utils/voice_listen_start.dart';
import '../../utils/quiz_voice_route_aware.dart';
import '../widgets/api_disclaimer_section.dart';
import '../widgets/quiz_voice_debug_panel.dart';
import '../widgets/quiz_voice_overlay.dart';

class McqScreen extends StatefulWidget {
  final String courseTitle;
  final String? examId;
  final List<dynamic>? questions;
  final int? totalQuestionCount;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final bool timedMode;
  final bool voiceModeEnabled;
  final bool voicePracticeMode;

  const McqScreen({
    super.key,
    required this.courseTitle,
    this.examId,
    this.questions,
    this.totalQuestionCount,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.timedMode = true,
    this.voiceModeEnabled = false,
    this.voicePracticeMode = false,
  });

  @override
  State<McqScreen> createState() => _McqScreenState();
}

class _McqScreenState extends State<McqScreen>
    with QuizVoiceRouteAware<McqScreen> {
  static const int _defaultDurationMinutes = 130;
  static const Duration _voiceAutoPlayDelay = Duration(seconds: 4);

  // ─── Exam state ────────────────────────────────────────────────────────────
  late final List<_Question> _questions;
  late final FlutterTts _tts;
  late final bool _isTimedSession;
  int _currentIndex = 0;
  final Map<int, Set<int>> _selectedIndexes = {};
  final Set<int> _lockedQuestions = {};
  final Set<int> _flaggedQuestions = {};
  bool _showExplanation = false;
  bool _isSpeaking = false;
  Timer? _timer;
  Timer? _voiceAutoAdvanceTimer;
  Duration? _remaining;
  bool _hasAutoSubmitted = false;
  bool _isAutoSubmitting = false;
  bool _voicePracticePaused = false;
  late final DateTime _voiceSessionStartedAt;
  int _voiceCorrectCount = 0;
  int _voiceIncorrectCount = 0;
  int _voiceSkippedCount = 0;
  int _voiceMultiCorrectCount = 0;
  int _voiceMultiAttemptCount = 0;
  int _voiceTrueFalseCorrectCount = 0;
  int _voiceTrueFalseAttemptCount = 0;

  // ─── Voice state ───────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _voiceModeEnabled = false;
  bool _isListening = false;
  bool _isPreparingToListen = false;
  bool _speechAvailable = false;
  bool _speechInitializing = false;
  Timer? _listeningRestartTimer;
  Timer? _voiceLoopRecoveryTimer;
  String? _speechLocaleId;
  String _heardText = '';
  final VoiceCommandProcessor _voiceCommandProcessor = VoiceCommandProcessor();
  bool _isQuestionNarrationActive = false;
  int _ttsSessionId = 0;
  final String _voiceScreenToken =
      'mcq-${DateTime.now().microsecondsSinceEpoch}';

  QuizVoiceController get _voiceController =>
      Get.isRegistered<QuizVoiceController>()
      ? Get.find<QuizVoiceController>()
      : Get.put(QuizVoiceController(), permanent: true);

  int get _settingsQuestionCount {
    final total = widget.totalQuestionCount;
    if (total != null && total > 0) return total;
    return _questions.length;
  }

  bool get _autoListenEnabled =>
      _voiceController.assistantSettings.value.autoListenOnScreenOpen;
  bool get _isCurrentVoiceScreen =>
      _voiceController.isCurrentScreenToken(_voiceScreenToken);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions(widget.questions);
    _tts = FlutterTts();
    _voiceSessionStartedAt = DateTime.now();
    _voiceModeEnabled =
        widget.voicePracticeMode &&
        (widget.voiceModeEnabled || _voiceController.isEnabledValue);
    _configureTts();
    unawaited(_primeSpeechAvailability());
    final UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    final bool isPro = userController.planTier.value == PlanTier.professional;
    _isTimedSession = widget.timedMode && isPro;
    if (_isTimedSession) {
      _setupTimer();
    } else {
      _remaining = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activateVoiceScreen();
        _bindVoiceSession(requestEntryAction: _voiceModeEnabled);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voiceAutoAdvanceTimer?.cancel();
    _listeningRestartTimer?.cancel();
    _voiceLoopRecoveryTimer?.cancel();
    _voiceAutoAdvanceTimer?.cancel();
    unawaited(_stopTtsPlayback());
    unawaited(_speech.cancel());
    _voiceController.unbindScreen(
      QuizVoiceScreen.mcq,
      screenToken: _voiceScreenToken,
    );
    super.dispose();
  }

  void _activateVoiceScreen() {
    _voiceController.activateScreen(
      QuizVoiceScreen.mcq,
      _voiceScreenToken,
      onDeactivate: _hardStopInactiveVoice,
    );
  }

  Future<void> _hardStopInactiveVoice() async {
    _listeningRestartTimer?.cancel();
    _voiceLoopRecoveryTimer?.cancel();
    await _stopTtsPlayback();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
    });
  }

  // ─── TTS configuration ─────────────────────────────────────────────────────

  Future<void> _configureTts() async {
    await _applyVoiceAssistantSettings();
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!mounted || !_isCurrentVoiceScreen) return;
      if (_isQuestionNarrationActive) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
      // In voice mode, auto-start listening after every TTS completion.
      if (_voiceModeEnabled && _autoListenEnabled && !_isListening) {
        _scheduleListeningRestart(const Duration(milliseconds: 500));
      }
    });
    _tts.setCancelHandler(() {
      if (!mounted || !_isCurrentVoiceScreen) return;
      if (_isQuestionNarrationActive) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
    });
    _tts.setErrorHandler((_) {
      if (!mounted || !_isCurrentVoiceScreen) return;
      if (_isQuestionNarrationActive) return;
      setState(() => _isSpeaking = false);
      _syncVoiceSessionState();
    });
  }

  Future<void> _applyVoiceAssistantSettings() async {
    final settings = _voiceController.assistantSettings.value;
    await _tts.setLanguage(settings.languageCode);
    await _tts.setSpeechRate(settings.voiceSpeed);
    await _tts.setPitch(settings.voicePitch);
  }

  void _bindVoiceSession({bool requestEntryAction = false}) {
    _voiceController.bindScreen(
      screen: QuizVoiceScreen.mcq,
      screenToken: _voiceScreenToken,
      onRecoverListening: () async {
        await _forceVoiceRecovery();
      },
      onEntryAction: () async {
        if (!mounted || !_voiceModeEnabled || _isAutoSubmitting) return;
        await _speakCurrentQuestion();
      },
      requestEntryAction: requestEntryAction && _autoListenEnabled,
    );
    _syncVoiceSessionState();
  }

  Future<void> _forceVoiceRecovery() async {
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isAutoSubmitting) {
      return;
    }
    _voiceController.logEvent(
      'force voice recovery',
      screen: QuizVoiceScreen.mcq,
    );
    _listeningRestartTimer?.cancel();
    _voiceLoopRecoveryTimer?.cancel();
    await _stopTtsPlayback();
    await _speech.cancel();
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isAutoSubmitting) {
      return;
    }
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
      _heardText = '';
    });
    _voiceController.setVoiceState(
      VoiceState.idle,
      screen: QuizVoiceScreen.mcq,
    );
    _syncVoiceSessionState();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted ||
        !_isCurrentVoiceScreen ||
        !_voiceModeEnabled ||
        _isAutoSubmitting ||
        _isSpeaking) {
      return;
    }
    await _startListening();
  }

  @override
  void onVoiceRouteActive() {
    if (!mounted) return;
    _activateVoiceScreen();
    _bindVoiceSession(requestEntryAction: _voiceModeEnabled);
  }

  @override
  void onVoiceRouteInactive() {
    if (_voiceModeEnabled) _voiceController.beginNavigation();
    _voiceController.deactivateScreen(_voiceScreenToken);
  }

  void _syncVoiceSessionState() {
    _voiceController.setVoiceEnabled(
      _voiceModeEnabled,
      screen: QuizVoiceScreen.mcq,
    );
    _voiceController.markHeardText(_heardText);
    if (!_voiceModeEnabled) return;
    final phase = _isAutoSubmitting
        ? QuizVoicePhase.submitting
        : _isSpeaking
        ? QuizVoicePhase.speaking
        : _isListening
        ? QuizVoicePhase.listening
        : QuizVoicePhase.idle;
    _voiceController.setPhase(phase, screen: QuizVoiceScreen.mcq);
  }

  // ─── STT initialisation ────────────────────────────────────────────────────

  Future<void> _primeSpeechAvailability() async {
    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _speechLocaleId = null;
      });
      return;
    }
    await _initSpeech();
  }

  Future<bool> _initSpeech({bool requestPermission = false}) async {
    if (_speechInitializing) return _speechAvailable;
    if (!requestPermission && !_speechAvailable) {
      final hasPermission = await _speech.hasPermission;
      if (!hasPermission) {
        if (!mounted) return false;
        setState(() {
          _speechAvailable = false;
          _speechLocaleId = null;
        });
        return false;
      }
    }

    _speechInitializing = true;
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (!mounted || !_isCurrentVoiceScreen) return;
          _voiceController.logEvent(
            'speech error: $error',
            screen: QuizVoiceScreen.mcq,
          );
          setState(() {
            _isListening = false;
            _isPreparingToListen = false;
          });
          _syncVoiceSessionState();
          _scheduleListeningRestart();
        },
        onStatus: (status) {
          if (!mounted || !_isCurrentVoiceScreen) return;
          _voiceController.logEvent(
            'speech status: $status',
            screen: QuizVoiceScreen.mcq,
          );
          _voiceController.onSpeechStatus(
            status,
            screen: QuizVoiceScreen.mcq,
            screenToken: _voiceScreenToken,
          );
          if (status == 'listening' &&
              (!_isListening || _isPreparingToListen)) {
            setState(() {
              _isListening = true;
              _isPreparingToListen = false;
            });
            _syncVoiceSessionState();
          }
          if (status == 'done' || status == 'notListening') {
            if (_isListening || _isPreparingToListen) {
              setState(() {
                _isListening = false;
                _isPreparingToListen = false;
              });
              _syncVoiceSessionState();
            }
            _scheduleListeningRestart();
          }
        },
        options: [SpeechToText.androidNoBluetooth],
      );
      String? preferredLocaleId;
      if (available) {
        preferredLocaleId = await _resolvePreferredSpeechLocaleId();
      }
      if (mounted) {
        setState(() {
          _speechAvailable = available;
          _speechLocaleId = preferredLocaleId;
        });
      }
      if (_voiceModeEnabled && available) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _voiceModeEnabled && !_isSpeaking) {
            unawaited(_speakCurrentQuestion());
          }
        });
      }
      return available;
    } catch (error, stackTrace) {
      _voiceController.logEvent(
        'speech initialize failed: $error\n$stackTrace',
        screen: QuizVoiceScreen.mcq,
      );
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _speechLocaleId = null;
        });
      }
      return false;
    } finally {
      _speechInitializing = false;
    }
  }

  Future<void> _showSpeechUnavailableMessage() async {
    final hasPermission = await _speech.hasPermission;
    if (!mounted) return;
    final message = hasPermission
        ? 'Speech recognition is not available on this device right now.'
        : 'Microphone permission is required for voice mode. If you denied it before, enable Microphone for this app in Android settings and try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleListeningRestart([
    Duration delay = const Duration(milliseconds: 700),
  ]) {
    _listeningRestartTimer?.cancel();
    if (!_voiceModeEnabled || !_autoListenEnabled) return;
    final retryDelay = enforceMinimumVoiceListenRetryDelay(delay);
    if (mounted &&
        !_isListening &&
        !_isSpeaking &&
        !_isAutoSubmitting &&
        !_isPreparingToListen) {
      setState(() => _isPreparingToListen = true);
    }
    _listeningRestartTimer = Timer(retryDelay, () {
      if (!mounted ||
          !_isCurrentVoiceScreen ||
          !_voiceModeEnabled ||
          _isListening ||
          _isSpeaking ||
          _isAutoSubmitting) {
        return;
      }
      unawaited(_startListening());
    });
  }

  void _scheduleVoiceLoopRecovery({
    Duration delay = const Duration(milliseconds: 1200),
    int retries = 5,
  }) {
    _voiceLoopRecoveryTimer?.cancel();
    if (!_voiceModeEnabled || retries <= 0) return;
    final retryDelay = enforceMinimumVoiceListenRetryDelay(delay);
    _voiceLoopRecoveryTimer = Timer(retryDelay, () {
      if (!mounted ||
          !_isCurrentVoiceScreen ||
          !_voiceModeEnabled ||
          _isListening) {
        return;
      }
      if (_isSpeaking) {
        _scheduleVoiceLoopRecovery(
          delay: minimumVoiceListenRetryDelay,
          retries: retries - 1,
        );
        return;
      }
      unawaited(_startListening());
      _scheduleVoiceLoopRecovery(
        delay: const Duration(milliseconds: 1200),
        retries: retries - 1,
      );
    });
  }

  Future<String?> _resolvePreferredSpeechLocaleId() async {
    try {
      final systemLocale = await _speech.systemLocale();
      final locales = await _speech.locales();
      final localeIds = locales.map((locale) => locale.localeId).toSet();
      final configuredLocaleId =
          _voiceController.assistantSettings.value.languageCode;
      final configuredSpeechLocaleId = configuredLocaleId.replaceAll('-', '_');
      if (localeIds.contains(configuredLocaleId)) return configuredLocaleId;
      if (localeIds.contains(configuredSpeechLocaleId)) {
        return configuredSpeechLocaleId;
      }

      final String? systemLocaleId = systemLocale?.localeId;
      if (systemLocaleId != null &&
          systemLocaleId.toLowerCase().startsWith('en')) {
        return systemLocaleId;
      }

      for (final fallback in ['en_IN', 'en_GB', 'en_US']) {
        if (localeIds.contains(fallback)) return fallback;
      }

      return systemLocaleId;
    } catch (_) {
      return null;
    }
  }

  // ─── Timer ─────────────────────────────────────────────────────────────────

  DateTime? _resolveEndTime() {
    final now = DateTime.now();
    final int durationMinutes =
        (widget.durationMinutes != null && widget.durationMinutes! > 0)
        ? widget.durationMinutes!
        : _defaultDurationMinutes;
    final Duration duration = Duration(minutes: durationMinutes);
    DateTime? endTime = widget.endTime;

    if (endTime == null && widget.startTime != null) {
      endTime = widget.startTime!.add(duration);
    }
    endTime ??= now.add(duration);

    if (endTime.isBefore(now)) {
      endTime = now.add(duration);
    }
    if (widget.startTime != null && widget.startTime!.isAfter(now)) {
      endTime = now.add(duration);
    }

    return endTime;
  }

  void _setupTimer() {
    _timer?.cancel();
    if (!_isTimedSession) {
      _remaining = null;
      return;
    }
    final DateTime? endTime = _resolveEndTime();
    if (endTime == null) return;

    final remaining = endTime.difference(DateTime.now());
    _remaining = remaining.isNegative ? Duration.zero : remaining;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = endTime.difference(DateTime.now());
      if (!mounted) return;
      if (remaining <= Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _timer?.cancel();
        _handleTimeExpired();
        return;
      }
      setState(() => _remaining = remaining);
    });
  }

  void _handleTimeExpired() {
    if (_hasAutoSubmitted) return;
    _hasAutoSubmitted = true;
    unawaited(_stopTtsPlayback());
    unawaited(_speech.cancel());
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isAutoSubmitting = true;
    });
    _syncVoiceSessionState();
    _goToExamReview(autoSubmit: true);
  }

  // ─── Question building ─────────────────────────────────────────────────────

  List<_Question> _buildQuestions(List<dynamic>? rawQuestions) {
    final parsed = _parseQuestions(rawQuestions);
    if (parsed.isNotEmpty) return parsed;
    return List<_Question>.generate(20, (index) {
      return _Question(
        number: index + 1,
        text: 'Q${index + 1}. When I think about my childhood, I feel:',
        options: const [
          'Nostalgic and warm',
          'Disconnected or uncertain',
          'Some unresolved pain or sadness',
          'Grateful for the lessons learned',
        ],
        correctIndexes: const {2},
        codeReference: 'API 510, Section 3 (Definitions) - "Alteration"',
        explanation:
            'An alteration is a change that affects the pressure-retaining capability or design conditions of a pressure vessel.\n\nA change in design temperature directly affects allowable stress and MAWP, so it is classified as an alteration.\n\n• D (weld buildup to restore metal loss) is a repair, not an alteration, because it restores the vessel to its original design condition.',
        type: _QuestionType.single,
      );
    });
  }

  int? _optionIndexFromLetter(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.length != 1) return null;
    final code = trimmed.codeUnitAt(0);
    if (code < 65 || code > 90) return null;
    return code - 65;
  }

  _QuestionType _resolveQuestionType(
    Map<String, dynamic> data,
    List<String> options,
    Set<int> correctIndexes,
  ) {
    final rawType =
        data['questionType'] ??
        data['type'] ??
        (data['metadata'] is Map ? data['metadata']['type'] : null);
    final typeText = rawType?.toString().trim().toLowerCase() ?? '';
    if (typeText.contains('multi') ||
        typeText.contains('select all') ||
        typeText.contains('multiple')) {
      return _QuestionType.multiSelect;
    }
    if (typeText.contains('true') || typeText.contains('false')) {
      return _QuestionType.trueFalse;
    }
    final normalizedOptions = options
        .map((option) => option.trim().toLowerCase())
        .toSet();
    if (normalizedOptions.length == 2 &&
        normalizedOptions.contains('true') &&
        normalizedOptions.contains('false')) {
      return _QuestionType.trueFalse;
    }
    if (correctIndexes.length > 1) return _QuestionType.multiSelect;
    return _QuestionType.single;
  }

  List<_Question> _parseQuestions(List<dynamic>? rawQuestions) {
    if (rawQuestions == null || rawQuestions.isEmpty) return [];

    final List<_Question> parsed = [];
    for (int i = 0; i < rawQuestions.length; i++) {
      final raw = rawQuestions[i];
      if (raw is! Map) {
        if (raw is String) {
          parsed.add(
            _Question(
              number: i + 1,
              text: raw,
              options: const ['Option A', 'Option B', 'Option C', 'Option D'],
              correctIndexes: const {},
              codeReference: '',
              explanation: '',
              type: _QuestionType.single,
            ),
          );
        }
        continue;
      }
      final data = Map<String, dynamic>.from(raw);
      final String text =
          (data['question'] ??
                  data['text'] ??
                  data['prompt'] ??
                  'Question ${i + 1}')
              .toString();

      final dynamic rawOptions =
          data['options'] ?? data['choices'] ?? data['answers'];
      final List<String> options = [];
      final Set<int> correctIndexes = {};

      if (rawOptions is List) {
        for (int optIndex = 0; optIndex < rawOptions.length; optIndex++) {
          final option = rawOptions[optIndex];
          if (option is Map) {
            final optionText =
                option['option'] ??
                option['text'] ??
                option['label'] ??
                option['value'] ??
                option['answer'];
            if (optionText != null) options.add(optionText.toString());
            final bool isCorrect =
                option['is_correct'] == true ||
                option['isCorrect'] == true ||
                option['correct'] == true;
            if (isCorrect) correctIndexes.add(optIndex);
          } else {
            options.add(option.toString());
          }
        }
      }

      if (correctIndexes.isEmpty) {
        final dynamic correctAnswer =
            data['correctAnswer'] ??
            data['answer'] ??
            data['correct'] ??
            data['correctAnswers'] ??
            data['correct_options'];
        final values = correctAnswer is List ? correctAnswer : [correctAnswer];
        for (final value in values) {
          if (value is int && value >= 0 && value < options.length) {
            correctIndexes.add(value);
          } else if (value is String) {
            final splitValues = value.contains(',')
                ? value.split(',').map((item) => item.trim())
                : <String>[value.trim()];
            for (final item in splitValues) {
              final optionLetterIndex = _optionIndexFromLetter(item);
              if (optionLetterIndex != null &&
                  optionLetterIndex < options.length) {
                correctIndexes.add(optionLetterIndex);
                continue;
              }
              final idx = options.indexWhere(
                (opt) => opt.toLowerCase().trim() == item.toLowerCase().trim(),
              );
              if (idx >= 0) correctIndexes.add(idx);
            }
          }
        }
      }

      final String codeReference =
          (data['codeReference'] ??
                  data['reference'] ??
                  data['source'] ??
                  data['citation'] ??
                  '')
              .toString();
      final String explanation =
          (data['explanation'] ?? data['rationale'] ?? data['reason'] ?? '')
              .toString();

      if (options.isEmpty) {
        options.addAll(const ['Option A', 'Option B', 'Option C', 'Option D']);
      }

      final questionType = _resolveQuestionType(data, options, correctIndexes);

      parsed.add(
        _Question(
          number: i + 1,
          text: text,
          options: options,
          correctIndexes: correctIndexes,
          codeReference: codeReference,
          explanation: explanation,
          type: questionType,
        ),
      );
    }

    return parsed;
  }

  // ─── Exam actions ──────────────────────────────────────────────────────────

  Set<int> _selectedFor(int questionIndex) {
    return _selectedIndexes[questionIndex] ?? const <int>{};
  }

  bool _hasAnswer(int questionIndex) => _selectedFor(questionIndex).isNotEmpty;

  bool _isAnswerCorrect(_Question question, Set<int> selected) {
    return selected.isNotEmpty &&
        question.correctIndexes.isNotEmpty &&
        selected.length == question.correctIndexes.length &&
        selected.every(question.correctIndexes.contains);
  }

  String _lettersFor(Set<int> indexes) {
    final letters = indexes.toList()..sort();
    if (letters.isEmpty) return '';
    if (letters.length == 1) return String.fromCharCode(65 + letters.first);
    return letters
        .map((index) => String.fromCharCode(65 + index))
        .join(' and ');
  }

  void _onSelect(int index) {
    if (_lockedQuestions.contains(_currentIndex)) return;
    final question = _questions[_currentIndex];
    setState(() {
      if (question.isMultiSelect) {
        final selected = Set<int>.from(_selectedFor(_currentIndex));
        if (selected.contains(index)) {
          selected.remove(index);
        } else {
          selected.add(index);
        }
        if (selected.isEmpty) {
          _selectedIndexes.remove(_currentIndex);
        } else {
          _selectedIndexes[_currentIndex] = selected;
        }
        return;
      }
      _selectedIndexes[_currentIndex] = {index};
      final correctIndex = question.correctIndex;
      if (correctIndex != null && index != correctIndex) {
        _lockedQuestions.add(_currentIndex);
      }
    });
  }

  void _onNext() async {
    final bool hasAnswer = _hasAnswer(_currentIndex);
    final bool isFlagged = _flaggedQuestions.contains(_currentIndex);
    if (!hasAnswer && !isFlagged) return;
    if (_currentIndex < _questions.length - 1) {
      unawaited(_stopTtsPlayback());
      setState(() {
        _currentIndex += 1;
        _showExplanation = false;
        _isSpeaking = false;
      });
      return;
    }
    await _openExamReview();
  }

  void _toggleFlag() {
    setState(() {
      if (_flaggedQuestions.contains(_currentIndex)) {
        _flaggedQuestions.remove(_currentIndex);
      } else {
        _flaggedQuestions.add(_currentIndex);
      }
    });
  }

  void _toggleExplanation() {
    final bool canView = _hasAnswer(_currentIndex);
    if (!canView) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an answer first to view explanation.'),
        ),
      );
      return;
    }
    setState(() => _showExplanation = !_showExplanation);
  }

  // ─── TTS ───────────────────────────────────────────────────────────────────

  String _normalizeSpeechText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _shortSpeechText(String text, {int maxLength = 600}) {
    final normalized = _normalizeSpeechText(text);
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength).trim()}...';
  }

  List<String> _buildQuestionSpeechSegments(_Question question) {
    final segments = <String>[
      'Question ${question.number}.',
      if (question.isMultiSelect) 'Select all that apply.',
      _normalizeSpeechText(question.text),
    ];

    for (int i = 0; i < question.options.length; i++) {
      final label = String.fromCharCode(65 + i);
      final optionText = _normalizeSpeechText(question.options[i]);
      if (optionText.isEmpty) continue;
      segments.add('Option $label. $optionText.');
    }

    if (_voiceModeEnabled && question.options.isNotEmpty) {
      if (question.isTrueFalse) {
        segments.add('Please say true or false.');
      } else if (question.isMultiSelect) {
        segments.add(
          'You may select more than one answer. Say something like A and C.',
        );
      } else {
        segments.add(
          'Please say A, B, C, or D. You can also say next, review, or help.',
        );
      }
    }

    return segments.where((segment) => segment.isNotEmpty).toList();
  }

  Future<void> _stopTtsPlayback() async {
    _ttsSessionId++;
    _isQuestionNarrationActive = false;
    await _tts.stop();
  }

  Future<void> _speakCurrentQuestion({bool force = false}) async {
    _voiceController.logEvent(
      'speak current question',
      screen: QuizVoiceScreen.mcq,
    );
    final _Question question = _questions[_currentIndex];
    final segments = _buildQuestionSpeechSegments(question);
    final questionKey = widget.examId?.trim().isNotEmpty == true
        ? widget.examId!.trim()
        : widget.courseTitle;
    final shouldSpeak = _voiceController.speakOnce(
      key: 'question_${questionKey}_$_currentIndex',
      text: segments.join(' '),
      force: force,
      screen: QuizVoiceScreen.mcq,
    );
    if (!shouldSpeak) {
      _scheduleListeningRestart();
      return;
    }
    await _speech.cancel();
    await _stopTtsPlayback();
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    _syncVoiceSessionState();
    await _applyVoiceAssistantSettings();
    final sessionId = ++_ttsSessionId;
    _isQuestionNarrationActive = true;

    try {
      for (final segment in segments) {
        if (!mounted || sessionId != _ttsSessionId) return;
        await _tts.speak(segment);
      }
    } catch (_) {
      // Let the voice recovery flow reopen listening if TTS fails mid-read.
    } finally {
      _isQuestionNarrationActive = false;
      final isActiveSession = mounted && sessionId == _ttsSessionId;
      if (isActiveSession) {
        setState(() => _isSpeaking = false);
        _syncVoiceSessionState();
        if (_voiceModeEnabled && _autoListenEnabled && !_isListening) {
          _scheduleListeningRestart(const Duration(milliseconds: 500));
        }
      }
    }
  }

  Future<void> _toggleSpeak() async {
    if (_isSpeaking) {
      await _stopTtsPlayback();
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      return;
    }
    await _speakCurrentQuestion(force: true);
  }

  /// Speaks [text] and, in voice mode, auto-starts listening when done.
  Future<void> _speakFeedback(String text) async {
    _voiceController.logEvent(
      'speak feedback requested',
      screen: QuizVoiceScreen.mcq,
    );
    await _speech.cancel();
    await _stopTtsPlayback();
    await _applyVoiceAssistantSettings();
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    _syncVoiceSessionState();
    await _tts.speak(text);
  }

  // ─── Voice mode toggle ─────────────────────────────────────────────────────

  Future<void> _toggleVoiceMode() async {
    if (_voiceModeEnabled) {
      _listeningRestartTimer?.cancel();
      _voiceLoopRecoveryTimer?.cancel();
      await _stopTtsPlayback();
      await _speech.cancel();
      if (!mounted) return;
      setState(() {
        _voiceModeEnabled = false;
        _isListening = false;
        _isSpeaking = false;
        _heardText = '';
      });
      _syncVoiceSessionState();
      return;
    }

    final speechReady = await _initSpeech(requestPermission: true);
    if (!speechReady) {
      await _showSpeechUnavailableMessage();
      return;
    }

    setState(() {
      _voiceModeEnabled = true;
      _heardText = '';
    });
    _bindVoiceSession();
    // Auto-read the current question immediately.
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted && _voiceModeEnabled) {
      _voiceController.setVoiceEnabled(
        true,
        screen: QuizVoiceScreen.mcq,
        requestEntryAction: true,
      );
      await _speakCurrentQuestion();
    }
  }

  // ─── STT listening ─────────────────────────────────────────────────────────

  /// Start the mic. TTS must be finished before calling — they never overlap.
  Future<void> _startListening() async {
    if (!_isCurrentVoiceScreen) return;
    _voiceController.logEvent(
      'start listening requested',
      screen: QuizVoiceScreen.mcq,
    );
    _listeningRestartTimer?.cancel();
    _voiceLoopRecoveryTimer?.cancel();
    if (_isListening || _isSpeaking) return;
    setState(() {
      _isPreparingToListen = true;
      _heardText = '';
    });
    _voiceController.markHeardText(_heardText);
    await _tts.stop();
    if (!mounted || !_isCurrentVoiceScreen) return;
    if (!_speechAvailable) {
      final speechReady = await _initSpeech();
      if (!speechReady) {
        if (mounted) setState(() => _isPreparingToListen = false);
        return;
      }
    }
    _voiceController.logEvent(
      'speech listen call starting',
      screen: QuizVoiceScreen.mcq,
    );
    final started = await startSpeechListeningSafely(
      speech: _speech,
      controller: _voiceController,
      screen: QuizVoiceScreen.mcq,
      onResult: _onSpeechResult,
      localeId: _speechLocaleId,
    );
    if (!mounted || !_isCurrentVoiceScreen) return;
    if (!started) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _syncVoiceSessionState();
      _voiceController.logEvent(
        'speech listen did not start, retry scheduled',
        screen: QuizVoiceScreen.mcq,
      );
      _scheduleListeningRestart();
      return;
    }
    setState(() {
      _isListening = true;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
    _voiceController.logEvent(
      'speech listen active',
      screen: QuizVoiceScreen.mcq,
    );
  }

  /// Tap-while-reading: stop TTS first, then open the mic.
  Future<void> _interruptAndListen() async {
    await _stopTtsPlayback();
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted && _isCurrentVoiceScreen) unawaited(_startListening());
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() {
      _isListening = false;
      _isPreparingToListen = false;
    });
    _syncVoiceSessionState();
  }

  List<dynamic> _reviewQuestions() {
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      return widget.questions!;
    }
    return _questions;
  }

  Future<void> _openExamReview({bool preserveVoiceMode = false}) async {
    _voiceLoopRecoveryTimer?.cancel();
    await _stopTtsPlayback();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
    });
    _syncVoiceSessionState();

    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.examReview);
    final result = await context.push<Object?>(
      '/exam-review',
      extra: {
        'courseTitle': widget.courseTitle,
        'examId': widget.examId,
        'questions': _reviewQuestions(),
        'selected': _selectedIndexes,
        'flagged': _flaggedQuestions,
        'voiceAnalytics': _buildVoiceAnalytics(),
        'voiceModeEnabled': preserveVoiceMode,
        'returnQuestionIndex': _currentIndex,
      },
    );

    if (!mounted) return;
    if (result is int) {
      setState(() {
        _currentIndex = result.clamp(0, _questions.length - 1);
        _showExplanation = false;
        _isSpeaking = false;
        _isListening = false;
        _heardText = '';
      });
      _bindVoiceSession(requestEntryAction: preserveVoiceMode);
    } else if (preserveVoiceMode) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
        _heardText = '';
      });
      _bindVoiceSession(requestEntryAction: true);
    }

    if (preserveVoiceMode && _voiceModeEnabled) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _voiceModeEnabled) {
          _scheduleVoiceLoopRecovery();
          unawaited(_speakCurrentQuestion());
        }
      });
    }
  }

  void _goToExamReview({
    bool autoSubmit = false,
    bool preserveVoiceMode = false,
  }) {
    _voiceController.beginNavigation(targetScreen: QuizVoiceScreen.examReview);
    context.go(
      '/exam-review',
      extra: {
        'courseTitle': widget.courseTitle,
        'examId': widget.examId,
        'questions': _reviewQuestions(),
        'selected': _selectedIndexes,
        'flagged': _flaggedQuestions,
        'voiceAnalytics': _buildVoiceAnalytics(),
        'autoSubmit': autoSubmit,
        'voiceModeEnabled': preserveVoiceMode,
        'returnQuestionIndex': _currentIndex,
      },
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || !_isCurrentVoiceScreen) return;
    setState(() => _heardText = result.recognizedWords);
    _voiceController.markHeardText(_heardText);
    _voiceController.logTranscript(
      result.recognizedWords,
      isFinal: result.finalResult,
      screen: QuizVoiceScreen.mcq,
    );
    if (result.finalResult) {
      setState(() {
        _isListening = false;
        _isPreparingToListen = false;
      });
      _voiceController.setPhase(
        QuizVoicePhase.processing,
        screen: QuizVoiceScreen.mcq,
      );
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) unawaited(_handleVoiceCommand(text));
    }
  }

  // ─── Voice command dispatcher ──────────────────────────────────────────────

  Future<void> _handleVoiceCommand(String rawText) async {
    if (_tryHandleQuestionAnswer(rawText)) return;

    final decision = await _voiceCommandProcessor.process(
      screen: QuizVoiceScreen.mcq,
      heardText: rawText,
      sensitivity: _voiceController.assistantSettings.value.commandSensitivity,
    );
    final result = decision.parseResult;
    final questionNumber = decision.questionNumber;
    _voiceController.logEvent(
      'parsed intent: ${result.intent?.name ?? 'none'}'
      '${questionNumber != null ? ' ($questionNumber)' : ''}'
      ' confidence: ${result.confidence.toStringAsFixed(2)}',
      screen: QuizVoiceScreen.mcq,
    );
    _voiceController.markCommandResult(
      command: result.intent == null
          ? null
          : QuizVoiceIntentParser.commandLabelFor(result.intent!),
      confidence: result.confidence,
      retry: decision.feedback,
    );
    if (!decision.shouldExecute && decision.feedback != null) {
      unawaited(_speakFeedback(decision.feedback!));
      return;
    }

    switch (decision.intent) {
      case VoiceIntent.optionA:
        _selectViaVoice(0);
        return;
      case VoiceIntent.optionB:
        _selectViaVoice(1);
        return;
      case VoiceIntent.optionC:
        _selectViaVoice(2);
        return;
      case VoiceIntent.optionD:
        _selectViaVoice(3);
        return;
      case VoiceIntent.next:
        _nextViaVoice();
        return;
      case VoiceIntent.back:
        _previousViaVoice();
        return;
      case VoiceIntent.questionNumber:
        if (questionNumber != null) {
          _goToQuestionViaVoice(questionNumber - 1);
          return;
        }
        break;
      case VoiceIntent.flag:
        _flagViaVoice();
        return;
      case VoiceIntent.repeat:
        unawaited(_speakCurrentQuestion(force: true));
        return;
      case VoiceIntent.explain:
        _explanationViaVoice();
        return;
      case VoiceIntent.review:
        _reviewViaVoice();
        return;
      case VoiceIntent.submit:
        _submitViaVoice();
        return;
      case VoiceIntent.stopVoice:
        unawaited(_disableVoiceModeWithFeedback('Voice mode turned off.'));
        return;
      case VoiceIntent.pauseAssistant:
        _voiceAutoAdvanceTimer?.cancel();
        _voicePracticePaused = true;
        unawaited(_speech.cancel());
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _isListening = false;
        });
        unawaited(
          _speakFeedback('Voice practice paused. Say resume to continue.'),
        );
        return;
      case VoiceIntent.resumeAssistant:
        _voicePracticePaused = false;
        unawaited(_speakFeedback('Voice practice resumed.'));
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted && _voiceModeEnabled) unawaited(_startListening());
        });
        return;
      case VoiceIntent.help:
        unawaited(
          _speakFeedback(
            'Available voice commands. '
            'To answer say first, second, third, or fourth. '
            'You can also say select A, select B, select C, or select D. '
            'Say next or skip to move forward. '
            'Say back to go to the previous question. '
            'Say question 5 to jump to any question. '
            'Say flag to bookmark a question. '
            'Say read to hear the question again. '
            'Say explain to hear the explanation. '
            'Say review to open the exam review screen. '
            'Say submit to open review and confirm the exam. '
            'Say stop voice mode to turn off hands free mode.',
          ),
        );
        return;
      default:
        break;
    }

    // ── Unrecognised ──
    final heard = rawText.trim().isNotEmpty ? 'I heard "$rawText". ' : '';
    unawaited(
      _speakFeedback(
        '${heard}Not recognised. '
        'Try one of these commands: first, second, next, review, or help.',
      ),
    );
  }

  // ─── Voice actions ─────────────────────────────────────────────────────────

  void _selectViaVoice(int optionIndex) {
    final question = _questions[_currentIndex];

    if (optionIndex >= question.options.length) {
      unawaited(_speakFeedback("That option doesn't exist for this question."));
      return;
    }
    if (_lockedQuestions.contains(_currentIndex)) {
      final letter = question.correctIndex != null
          ? String.fromCharCode(65 + question.correctIndex!)
          : '';
      unawaited(
        _speakFeedback(
          letter.isNotEmpty
              ? 'This question is already answered. The correct answer was $letter.'
              : 'This question is already answered.',
        ),
      );
      return;
    }
    if (_selectedFor(_currentIndex).contains(optionIndex) &&
        !question.isMultiSelect) {
      unawaited(_speakFeedback('You already selected that option.'));
      return;
    }

    _answerViaVoice({optionIndex});
  }

  bool _tryHandleQuestionAnswer(String rawText) {
    final question = _questions[_currentIndex];
    final parsed = _parseVoiceAnswerIndexes(rawText, question);
    if (parsed.isEmpty) return false;
    if (!question.isMultiSelect && parsed.length > 1) {
      unawaited(_speakFeedback('Please give one answer for this question.'));
      return true;
    }
    _answerViaVoice(parsed);
    return true;
  }

  Set<int> _parseVoiceAnswerIndexes(String rawText, _Question question) {
    final normalized = rawText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s,]'), ' ')
        .replaceAll(
          RegExp(
            r'\b(answer|answers|option|options|select|choose|letter|and)\b',
          ),
          ' ',
        )
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return const <int>{};

    if (question.isTrueFalse) {
      final wantsTrue = RegExp(r'\btrue\b').hasMatch(normalized);
      final wantsFalse = RegExp(r'\bfalse\b').hasMatch(normalized);
      if (wantsTrue == wantsFalse) return const <int>{};
      final target = wantsTrue ? 'true' : 'false';
      final index = question.options.indexWhere(
        (option) => option.trim().toLowerCase() == target,
      );
      if (index >= 0) return {index};
    }

    final indexes = <int>{};
    final tokens = normalized.split(RegExp(r'\s+'));
    const wordIndexes = <String, int>{
      'a': 0,
      'ay': 0,
      'one': 0,
      'first': 0,
      'b': 1,
      'bee': 1,
      'be': 1,
      'two': 1,
      'second': 1,
      'c': 2,
      'see': 2,
      'sea': 2,
      'three': 2,
      'third': 2,
      'd': 3,
      'dee': 3,
      'four': 3,
      'fourth': 3,
    };
    for (final token in tokens) {
      final index = wordIndexes[token];
      if (index != null && index < question.options.length) {
        indexes.add(index);
      }
    }
    if (!question.isMultiSelect && indexes.length > 1) return const <int>{};
    return indexes;
  }

  void _answerViaVoice(Set<int> selectedIndexes) {
    final question = _questions[_currentIndex];
    if (selectedIndexes.isEmpty) return;
    if (selectedIndexes.any((index) => index >= question.options.length)) {
      unawaited(_speakFeedback("That option doesn't exist for this question."));
      return;
    }

    final selected = Set<int>.from(selectedIndexes);
    final correct = _isAnswerCorrect(question, selected);
    setState(() {
      _selectedIndexes[_currentIndex] = selected;
      _lockedQuestions.add(_currentIndex);
      _showExplanation = true;
    });

    _recordVoiceAnswer(question, correct);

    final selectedLetters = _lettersFor(selected);
    final correctLetters = _lettersFor(question.correctIndexes);
    final explanation = question.explanation.isNotEmpty
        ? _shortSpeechText(question.explanation)
        : 'No explanation available for this question.';
    final modePrompt = widget.voicePracticeMode
        ? (_currentIndex < _questions.length - 1
              ? ' I will continue in a few seconds. You can say next, repeat, explain again, pause, or stop voice mode.'
              : ' Say submit when you are ready to finish.')
        : ' Say next to continue.';
    final correctness = question.correctIndexes.isEmpty
        ? ''
        : correct
        ? ' That is correct.'
        : ' That is incorrect. The correct answer is $correctLetters.';

    unawaited(
      _speakFeedback(
        'You selected $selectedLetters.$correctness Explanation. $explanation$modePrompt',
      ).then((_) {
        if (widget.voicePracticeMode && correct && mounted) {
          _scheduleVoiceAutoAdvance();
        } else if (widget.voicePracticeMode && mounted) {
          _scheduleVoiceAutoAdvance();
        }
      }),
    );
  }

  void _recordVoiceAnswer(_Question question, bool correct) {
    if (!widget.voicePracticeMode) return;
    if (correct) {
      _voiceCorrectCount += 1;
    } else {
      _voiceIncorrectCount += 1;
    }
    if (question.isMultiSelect) {
      _voiceMultiAttemptCount += 1;
      if (correct) _voiceMultiCorrectCount += 1;
    }
    if (question.isTrueFalse) {
      _voiceTrueFalseAttemptCount += 1;
      if (correct) _voiceTrueFalseCorrectCount += 1;
    }
  }

  void _nextViaVoice() {
    _voiceAutoAdvanceTimer?.cancel();
    final hasAnswer = _hasAnswer(_currentIndex);
    final isFlagged = _flaggedQuestions.contains(_currentIndex);

    if (!hasAnswer && !isFlagged) {
      if (widget.voicePracticeMode) {
        _voiceSkippedCount += 1;
      } else {
        unawaited(
          _speakFeedback(
            'Please select an answer or flag this question before moving on.',
          ),
        );
        return;
      }
    }

    if (_currentIndex < _questions.length - 1) {
      unawaited(_stopTtsPlayback());
      unawaited(_speech.cancel());
      setState(() {
        _currentIndex += 1;
        _showExplanation = false;
        _isSpeaking = false;
        _isListening = false;
        _heardText = '';
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _voiceModeEnabled) unawaited(_speakCurrentQuestion());
      });
    } else {
      final covered = <int>{..._selectedIndexes.keys, ..._flaggedQuestions};
      if (covered.length < _questions.length) {
        unawaited(
          _speakFeedback(
            'You still have unanswered questions. Say submit when you are ready.',
          ),
        );
      } else {
        unawaited(
          _speakFeedback(
            'You have reached the last question. Say submit to finish, or say back to review.',
          ),
        );
      }
    }
  }

  void _previousViaVoice() {
    _voiceAutoAdvanceTimer?.cancel();
    if (_currentIndex > 0) {
      unawaited(_stopTtsPlayback());
      unawaited(_speech.cancel());
      setState(() {
        _currentIndex -= 1;
        _showExplanation = false;
        _isSpeaking = false;
        _isListening = false;
        _heardText = '';
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _voiceModeEnabled) unawaited(_speakCurrentQuestion());
      });
    } else {
      unawaited(_speakFeedback('You are already on the first question.'));
    }
  }

  void _goToQuestionViaVoice(int index) {
    _voiceAutoAdvanceTimer?.cancel();
    if (index < 0 || index >= _questions.length) {
      unawaited(
        _speakFeedback(
          'Question ${index + 1} does not exist. '
          'There are ${_questions.length} questions total.',
        ),
      );
      return;
    }
    unawaited(_stopTtsPlayback());
    unawaited(_speech.cancel());
    setState(() {
      _currentIndex = index;
      _showExplanation = false;
      _isSpeaking = false;
      _isListening = false;
      _heardText = '';
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _voiceModeEnabled) unawaited(_speakCurrentQuestion());
    });
  }

  void _flagViaVoice() {
    _toggleFlag();
    final nowFlagged = _flaggedQuestions.contains(_currentIndex);
    unawaited(
      _speakFeedback(nowFlagged ? 'Question flagged.' : 'Flag removed.'),
    );
  }

  void _explanationViaVoice() {
    final hasAnswer = _hasAnswer(_currentIndex);
    if (!hasAnswer) {
      unawaited(
        _speakFeedback(
          'Please select an answer first to view the explanation.',
        ),
      );
      return;
    }
    if (!_showExplanation) setState(() => _showExplanation = true);
    final question = _questions[_currentIndex];
    final text = question.explanation.isNotEmpty
        ? _shortSpeechText(question.explanation)
        : 'No explanation available for this question.';
    unawaited(_speakFeedback('Explanation. $text'));
  }

  void _submitViaVoice() {
    _reviewViaVoice();
  }

  void _scheduleVoiceAutoAdvance() {
    _voiceAutoAdvanceTimer?.cancel();
    if (!widget.voicePracticeMode ||
        !_voiceModeEnabled ||
        _voicePracticePaused) {
      return;
    }
    if (_currentIndex >= _questions.length - 1) return;
    _voiceAutoAdvanceTimer = Timer(_voiceAutoPlayDelay, () {
      if (!mounted || !_voiceModeEnabled || _isSpeaking || _isListening) return;
      _nextViaVoice();
    });
  }

  Map<String, dynamic> _buildVoiceAnalytics() {
    final durationSeconds = DateTime.now()
        .difference(_voiceSessionStartedAt)
        .inSeconds;
    return {
      'voicePracticeMode': widget.voicePracticeMode,
      'voiceModeUsage': _voiceModeEnabled || widget.voiceModeEnabled,
      'sessionDurationSec': durationSeconds,
      'correctAnswers': _voiceCorrectCount,
      'incorrectAnswers': _voiceIncorrectCount,
      'skippedQuestions': _voiceSkippedCount,
      'flaggedQuestions': _flaggedQuestions.length,
      'multiSelectAccuracy': {
        'correct': _voiceMultiCorrectCount,
        'attempted': _voiceMultiAttemptCount,
      },
      'trueFalseAccuracy': {
        'correct': _voiceTrueFalseCorrectCount,
        'attempted': _voiceTrueFalseAttemptCount,
      },
    };
  }

  void _reviewViaVoice() {
    unawaited(_openExamReview(preserveVoiceMode: true));
  }

  Future<void> _disableVoiceModeWithFeedback(String message) async {
    _listeningRestartTimer?.cancel();
    _voiceLoopRecoveryTimer?.cancel();
    await _speech.cancel();
    await _stopTtsPlayback();
    if (!mounted) return;
    setState(() {
      _voiceModeEnabled = false;
      _isListening = false;
      _isSpeaking = false;
      _heardText = '';
    });
    _syncVoiceSessionState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final _Question question = _questions[_currentIndex];
    final Set<int> selected = _selectedFor(_currentIndex);
    final bool hasSelection = selected.isNotEmpty;
    final bool canViewExplanation = hasSelection;
    final bool isFlagged = _flaggedQuestions.contains(_currentIndex);
    final bool canGoNext =
        hasSelection || isFlagged || widget.voicePracticeMode;
    final String timerLabel = _remaining == null
        ? '--:--'
        : _formatDuration(_remaining!);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main scrollable content ──────────────────────────────────────
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Header row
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        unawaited(_stopTtsPlayback());
                        unawaited(_speech.cancel());
                        context.push(
                          '/quiz-settings',
                          extra: {
                            'courseTitle': widget.courseTitle,
                            'examId': widget.examId,
                            'questionCount': _settingsQuestionCount,
                            'selectedQuestionCount': _questions.length,
                          },
                        );
                      },
                      icon: const Icon(Icons.arrow_back, size: 22),
                    ),
                    Expanded(
                      child: Text(
                        widget.courseTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Info pills row — TTS + voice mode buttons
                Row(
                  children: [
                    _InfoPill(
                      label:
                          '${_selectedIndexes.length}/${_questions.length} Question Answered',
                    ),
                    if (_isTimedSession) ...[
                      const SizedBox(width: 8),
                      _InfoPill(icon: Icons.timer, label: timerLabel),
                    ],
                    const Spacer(),
                    if (!widget.voicePracticeMode)
                      IconButton(
                        onPressed: _toggleSpeak,
                        icon: Icon(
                          _isSpeaking ? Icons.volume_up : Icons.volume_off,
                          color: const Color(0xFF274B8A),
                        ),
                        tooltip: _isSpeaking ? 'Stop reading' : 'Read question',
                      ),
                    if (widget.voicePracticeMode)
                      _VoiceModeButton(
                        isEnabled: _voiceModeEnabled,
                        isListening: _isListening || _isPreparingToListen,
                        speechAvailable: _speechAvailable,
                        onTap: _toggleVoiceMode,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question number scroller
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _questions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final Set<int> sel = _selectedFor(index);
                      final bool isAnswered = sel.isNotEmpty;
                      final bool isFlag = _flaggedQuestions.contains(index);
                      final bool isCurrent = index == _currentIndex;
                      Color border = const Color(0xFF2D4F88);
                      Color fill = Colors.white;
                      Color textColor = const Color(0xFF111827);

                      if (isAnswered) {
                        if (_questions[index].correctIndexes.isNotEmpty) {
                          final bool isCorrect = _isAnswerCorrect(
                            _questions[index],
                            sel,
                          );
                          if (isCorrect) {
                            fill = const Color(0xFFD8F5D8);
                            border = const Color(0xFF2DBD67);
                            textColor = const Color(0xFF1B6C3E);
                          } else {
                            fill = const Color(0xFFFFD6D6);
                            border = const Color(0xFFE24B4B);
                            textColor = const Color(0xFFB42323);
                          }
                        } else {
                          fill = const Color(0xFFE7F0FF);
                          border = const Color(0xFF2F6DE0);
                          textColor = const Color(0xFF1E4C9A);
                        }
                      } else if (isFlag) {
                        fill = const Color(0xFFFFF4D6);
                        border = const Color(0xFFFFB020);
                        textColor = const Color(0xFFB76A00);
                      }
                      if (isCurrent) border = const Color(0xFF111827);

                      return GestureDetector(
                        onTap: () {
                          unawaited(_stopTtsPlayback());
                          unawaited(_speech.cancel());
                          setState(() {
                            _currentIndex = index;
                            _showExplanation = false;
                            _isSpeaking = false;
                            _isListening = false;
                            _heardText = '';
                          });
                          // Auto-read the tapped question in voice mode.
                          if (widget.voicePracticeMode && _voiceModeEnabled) {
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted && _voiceModeEnabled) {
                                  unawaited(_speakCurrentQuestion());
                                }
                              },
                            );
                          }
                        },
                        child: Container(
                          width: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 1.2),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Question text
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),

                // Answer options
                ...List.generate(question.options.length, (index) {
                  final String option = question.options[index];
                  final bool isSelected = selected.contains(index);
                  final bool isCorrect = question.correctIndexes.contains(
                    index,
                  );
                  final bool locked = _lockedQuestions.contains(_currentIndex);

                  Color borderColor = const Color(0xFFE5E7EB);
                  Color fillColor = const Color(0xFFF3F4F6);
                  Color textColor = const Color(0xFF111827);

                  if (hasSelection) {
                    if (question.correctIndexes.isNotEmpty) {
                      if (isCorrect) {
                        borderColor = const Color(0xFF2DBD67);
                        fillColor = const Color(0xFFD8F5D8);
                        textColor = const Color(0xFF1B6C3E);
                      }
                      if (isSelected && !isCorrect) {
                        borderColor = const Color(0xFFE24B4B);
                        fillColor = const Color(0xFFFFD6D6);
                        textColor = const Color(0xFFB42323);
                      }
                    } else if (isSelected) {
                      borderColor = const Color(0xFF2F6DE0);
                      fillColor = const Color(0xFFE7F0FF);
                      textColor = const Color(0xFF1E4C9A);
                    }
                  }

                  return GestureDetector(
                    onTap: locked ? null : () => _onSelect(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 1.4),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Flag button
                Center(
                  child: TextButton.icon(
                    onPressed: _toggleFlag,
                    icon: Icon(
                      Icons.flag,
                      color: isFlagged ? const Color(0xFFB76A00) : Colors.black,
                    ),
                    label: Text(
                      'Flag',
                      style: TextStyle(
                        color: isFlagged
                            ? const Color(0xFFB76A00)
                            : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Next button
                _PrimaryButton(
                  label: 'Next',
                  isEnabled: canGoNext,
                  onTap: _onNext,
                ),
                const SizedBox(height: 14),

                // Explanation toggle
                _DropdownHeader(
                  isExpanded: _showExplanation && canViewExplanation,
                  isEnabled: canViewExplanation,
                  onTap: _toggleExplanation,
                ),
                if (_showExplanation && canViewExplanation) ...[
                  const SizedBox(height: 12),
                  _ExplanationSection(
                    text: question.explanation.isNotEmpty
                        ? question.explanation
                        : 'No explanation available.',
                  ),
                ],
                const SizedBox(height: 18),
                const ApiDisclaimerSection(),

                // Extra bottom padding so the voice overlay never covers content.
                if (widget.voicePracticeMode && _voiceModeEnabled)
                  const SizedBox(height: 90),
              ],
            ),

            // ── Auto-submit overlay ──────────────────────────────────────────
            if (_isAutoSubmitting)
              Positioned.fill(
                child: Container(
                  color: const Color(0xAAFFFFFF),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            strokeWidth: 6,
                            color: Color(0xFF1E4C9A),
                            backgroundColor: Color(0xFFD5D8DE),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Time is up. Submitting...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Voice mode overlay (bottom) ──────────────────────────────────
            if (widget.voicePracticeMode && _voiceModeEnabled)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: QuizVoiceOverlay(
                  isListening: _isListening || _isPreparingToListen,
                  isPreparingToListen: _isPreparingToListen,
                  isSpeaking: _isSpeaking,
                  heardText: _heardText,
                  onMicTap: _isSpeaking
                      ? _interruptAndListen // tap while TTS reads → stop TTS then open mic
                      : (_isListening ? _stopListening : _startListening),
                  listeningHint:
                      'Say first, second, next, review, submit, or help.',
                  speakingHint: 'Assistant is reading the question.',
                  idleHint: 'Tap the mic or say an answer or command.',
                  instructionItems: const <String>[
                    'first',
                    'second',
                    'third',
                    'fourth',
                    'next',
                    'review',
                    'submit',
                    'help',
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

enum _QuestionType { single, multiSelect, trueFalse }

class _Question {
  final int number;
  final String text;
  final List<String> options;
  final Set<int> correctIndexes;
  final String codeReference;
  final String explanation;
  final _QuestionType type;

  const _Question({
    required this.number,
    required this.text,
    required this.options,
    required this.correctIndexes,
    required this.codeReference,
    required this.explanation,
    required this.type,
  });

  int? get correctIndex =>
      correctIndexes.length == 1 ? correctIndexes.first : null;

  bool get isMultiSelect => type == _QuestionType.multiSelect;
  bool get isTrueFalse => type == _QuestionType.trueFalse;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

// ─── Existing widgets ─────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _InfoPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: const Color(0xFF1E4C9A)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3A7D), Color(0xFF174A97)],
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownHeader extends StatelessWidget {
  final bool isExpanded;
  final bool isEnabled;
  final VoidCallback onTap;

  const _DropdownHeader({
    required this.isExpanded,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = isEnabled
        ? const Color(0xFF2F6DE0)
        : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor, width: 1.5),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'View Explanation',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  final String text;

  const _ExplanationSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.psychology, color: Color(0xFF2D4F88)),
            SizedBox(width: 8),
            Text(
              'Explanation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

// ─── New voice widgets ────────────────────────────────────────────────────────

/// Toggle button shown in the header row to enable/disable voice mode.
class _VoiceModeButton extends StatelessWidget {
  final bool isEnabled;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onTap;

  const _VoiceModeButton({
    required this.isEnabled,
    required this.isListening,
    required this.speechAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color iconColor;
    final IconData icon;
    final String tooltip;

    if (!speechAvailable) {
      bg = Colors.transparent;
      iconColor = Colors.grey.shade400;
      icon = Icons.mic_off;
      tooltip = 'Speech recognition unavailable';
    } else if (isEnabled) {
      bg = isListening ? const Color(0xFFFFE4E4) : const Color(0xFFDCFCE7);
      iconColor = isListening
          ? const Color(0xFFB91C1C)
          : const Color(0xFF166534);
      icon = Icons.mic;
      tooltip = 'Tap to turn off voice mode';
    } else {
      bg = Colors.transparent;
      iconColor = const Color(0xFF274B8A);
      icon = Icons.mic_none;
      tooltip = 'Tap to turn on voice mode';
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

/// Floating bar at the bottom of the screen shown when voice mode is active.
class _ListeningOverlay extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final String heardText;
  final VoidCallback onMicTap;

  const _ListeningOverlay({
    required this.isListening,
    required this.isSpeaking,
    required this.heardText,
    required this.onMicTap,
  });

  @override
  State<_ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<_ListeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _buildVoiceBars(Color color, {required bool active}) {
    return SizedBox(
      width: 38,
      height: 18,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final double wave = math.sin(
                (_pulse.value * math.pi * 2) + (index * 0.75),
              );
              final double height = active ? 6 + ((wave + 1) * 4.5) : 5;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 5,
                height: height.clamp(5, 15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: active ? 1 : 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool listening = widget.isListening;
    final bool speaking = widget.isSpeaking;

    final Color accentColor = listening
        ? const Color(0xFFEF4444)
        : speaking
        ? const Color(0xFF2D4F88)
        : const Color(0xFF5B6B88);

    final List<Color> panelGradient = listening
        ? const [Color(0xFFFFF1F2), Color(0xFFFFFFFF), Color(0xFFFFFBFB)]
        : speaking
        ? const [Color(0xFFF3F7FF), Color(0xFFFFFFFF), Color(0xFFF8FBFF)]
        : const [Color(0xFFF8FAFC), Color(0xFFFFFFFF), Color(0xFFF6F8FB)];

    final String statusText = listening
        ? 'Listening...'
        : speaking
        ? 'Speaking...'
        : 'Hands-free mode ready';

    final String helperText = listening
        ? 'Say your answer or command naturally.'
        : speaking
        ? 'Assistant is reading the next step.'
        : 'Tap mic anytime to interrupt and speak.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: panelGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.28),
            width: 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: widget.onMicTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (listening || speaking)
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  _MicCircle(bg: accentColor),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildVoiceBars(
                        accentColor,
                        active: listening || speaking,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    helperText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (widget.heardText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Heard: "${widget.heardText}"',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const QuizVoiceDebugPanel(),
                ],
              ),
            ),
            Tooltip(
              message:
                  'Answer: first / second / third / fourth\n'
                  'or: select A / select B / select C / select D\n'
                  'Other: next • back • flag • read • explain • submit',
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: accentColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicCircle extends StatelessWidget {
  final Color bg;
  const _MicCircle({required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [bg.withValues(alpha: 0.9), bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.mic, color: Colors.white, size: 20),
    );
  }
}
