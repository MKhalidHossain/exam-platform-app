# AGENTS.md — Voice Assistant Upgrade Agent for Flutter Quiz App

## Role

You are a senior Flutter engineer working on a quiz/exam application that already has a voice assistant using:

- `speech_to_text`
- `flutter_tts`

Your job is to upgrade the voice assistant so it works more reliably across different English accents and countries, supports fallback recognition, handles low-confidence commands safely, learns user corrections, and remains efficient, testable, and production-ready.

The user experience must be hands-free where possible, but safety and correctness are more important than guessing.

---

## Core Goal

Improve the existing voice assistant with this architecture:

```text
User Voice
  -> Audio capture / native speech_to_text
  -> Transcript normalization
  -> Screen-aware command parser
  -> Fuzzy matching
  -> Confidence scoring
  -> Execute safe commands
  -> Ask confirmation for uncertain/risky commands
  -> Cloud STT fallback when native STT fails
  -> User correction learning
  -> Analytics logging
```

The final result should make the app more reliable for users with different English accents, including African, Indian, UK, US, Australian, and other non-native English accents.

Do not claim that 100% global accent recognition is possible. Design the system to maximize reliability through fallback, correction, calibration, and safe confirmations.

---

## Existing Features To Preserve

The app already supports or intends to support:

- Speech-to-text voice command
- Text-to-speech feedback
- Voice quiz/practice mode
- Auto-read question
- MCQ answer selection by voice
- True/False answer support
- Multi-select answer parsing
- Voice quiz navigation:
  - next
  - skip
  - back
  - previous
  - question number jump
- Question actions:
  - repeat/read
  - flag/bookmark
  - explain
  - review
- Submit flow:
  - submit from quiz screen goes to review
  - submit + confirm submit from review screen finalizes quiz
- Review screen voice support:
  - unanswered
  - flagged
  - question number jump
  - repeat/help
- Quiz settings voice control:
  - start quiz
  - timed mode on/off
  - max/min questions
  - increase/decrease questions
  - set questions to N
- Exam session/loading voice control:
  - start test
  - back
  - help
  - status
  - retry
  - cancel
- Pause/resume voice assistant:
  - pause
  - quiet
  - stop reading
  - resume
  - continue listening
- Voice overlay UI:
  - speaking/listening/processing state
  - heard text
  - recognized command and confidence in debug mode
  - mic tap to interrupt/listen
- Voice settings:
  - speed
  - pitch
  - language code
  - auto-listen on screen open
  - command sensitivity: strict/normal/flexible
  - show/hide heard text
- Command learning/correction:
  - low-confidence command shows “Did you mean?”
  - user confirmation saves learned correction
  - unsafe submit/confirm-submit commands excluded from unsafe learning
- Voice session analytics:
  - duration
  - correct/incorrect count
  - skipped count
  - flagged count
  - multi-select accuracy
  - true/false accuracy

Do not remove these features unless the current implementation is broken and needs refactoring. Preserve public behavior.

---

## Non-Negotiable Requirements

### 1. Do Not Directly Trust Speech-To-Text

Never execute important actions directly from raw STT text.

Always process through:

```text
raw transcript -> normalize -> parse intent -> confidence check -> safety check -> execute/confirm/fallback
```

### 2. Use Screen-Aware Command Context

The parser must know which screen is active.

Examples:

Quiz screen commands:

- option A/B/C/D
- true/false
- next question
- previous question
- read question
- explain answer
- flag question
- open review
- submit quiz

Review screen commands:

- unanswered
- flagged
- question N
- read summary
- submit quiz
- confirm submit

Loading/session screen commands:

- start test
- retry
- cancel
- back
- help
- status

Settings screen commands:

- timed mode on/off
- increase/decrease questions
- set questions to N
- start quiz

Do not let every command match on every screen.

### 3. Risky Commands Must Be Protected

Risky commands include:

- submit quiz
- confirm submit
- final submit
- exit quiz
- reset answers
- clear answer
- finish exam
- delete
- restart test

Rules:

- Risky commands must not be executed from weak fuzzy matches.
- Risky commands must require strong confidence.
- Final submission must require explicit confirmation.
- Risky commands must not be auto-learned from user correction unless explicitly safe and reviewed.
- If uncertain, ask confirmation instead of executing.

### 4. Cloud STT Must Be Fallback, Not First Choice

Use native `speech_to_text` first.

Use cloud STT only when:

- native transcript is empty
- native confidence is low
- command parser cannot detect a command
- user’s selected mode allows online fallback
- connectivity is available

This keeps the app fast, cheaper, and more private.

### 5. No API Keys In Flutter App

Cloud STT provider keys must not be stored in Flutter.

Correct:

```text
Flutter app -> backend proxy -> STT provider
```

Wrong:

```text
Flutter app -> STT provider directly with secret API key
```

### 6. Voice Learning Must Be User-Specific

Correction learning should be stored per user/device/profile.

Example:

```json
{
  "rawHeardText": "opson bee",
  "normalizedText": "option b",
  "intent": "select_option",
  "value": "B",
  "screen": "quiz"
}
```

### 7. The App Must Still Work Offline

Offline mode should support:

- native `speech_to_text`
- command aliases
- fuzzy parser
- user corrections stored locally
- confirmation flow

Online mode can add cloud fallback.

---

## Recommended File Structure

Create or refactor toward this structure if compatible with the existing app:

```text
lib/voice/
  core/
    voice_intent.dart
    voice_command_context.dart
    voice_command_result.dart
    voice_confidence_level.dart
    voice_safety_policy.dart

  recognition/
    voice_recognition_service.dart
    native_speech_service.dart
    cloud_speech_service.dart
    voice_audio_recorder.dart

  parsing/
    voice_text_normalizer.dart
    voice_command_aliases.dart
    voice_command_parser.dart
    fuzzy_matcher.dart

  learning/
    voice_learning_service.dart
    voice_correction_model.dart

  analytics/
    voice_analytics_service.dart
    voice_command_log.dart

  controller/
    voice_assistant_controller.dart

  ui/
    voice_overlay_bar.dart
    voice_calibration_screen.dart
    voice_settings_screen.dart
```

If the existing project has a different architecture, adapt to it while keeping separation of concerns.

---

## Data Models

### VoiceIntent

Create a typed model for intents.

Suggested intents:

```dart
enum VoiceIntentType {
  selectOption,
  selectTrue,
  selectFalse,
  selectMultiOption,
  nextQuestion,
  previousQuestion,
  skipQuestion,
  jumpToQuestion,
  readQuestion,
  explainAnswer,
  flagQuestion,
  openReview,
  goToUnanswered,
  goToFlagged,
  readSummary,
  submitQuiz,
  confirmSubmit,
  cancelSubmit,
  startQuiz,
  startTest,
  retry,
  cancel,
  back,
  help,
  status,
  pauseAssistant,
  resumeAssistant,
  timedModeOn,
  timedModeOff,
  increaseQuestions,
  decreaseQuestions,
  setQuestionCount,
  unknown,
}
```

`VoiceIntent` should include:

```dart
class VoiceIntent {
  final VoiceIntentType type;
  final String? value;
  final int? number;
  final double confidence;
  final bool isRisky;
  final String rawText;
  final String normalizedText;
  final String source; // native, cloud, correction
}
```

### VoiceCommandContext

```dart
enum VoiceScreenContext {
  quiz,
  review,
  settings,
  session,
  loading,
  result,
  global,
}
```

### VoiceCommandResult

```dart
enum VoiceCommandDecision {
  execute,
  askConfirmation,
  fallbackToCloud,
  notUnderstood,
  ignored,
}
```

---

## Transcript Normalization Requirements

Implement `VoiceTextNormalizer`.

It must:

- lowercase text
- trim whitespace
- remove punctuation
- collapse repeated spaces
- convert common STT mistakes
- normalize option letters
- normalize numbers
- normalize known accent variants

Examples to handle:

```text
"option bee" -> "option b"
"option be" -> "option b"
"of shun b" -> "option b"
"opson bee" -> "option b"
"answer sea" -> "answer c"
"answer see" -> "answer c"
"option dee" -> "option d"
"tree" -> "three"
"free" -> "three"
"fals" -> "false"
"falls" -> "false"
"kweschen" -> "question"
"nex" -> "next"
```

Also support number words:

```text
one -> 1
two -> 2
three -> 3
four -> 4
five -> 5
...
twenty -> 20
```

Do not over-normalize in a way that causes dangerous commands to match accidentally.

---

## Command Alias Requirements

Build a central alias map.

Examples:

```dart
select A:
- option a
- answer a
- choose a
- select a
- first option
- option one

select B:
- option b
- answer b
- choose b
- select b
- second option
- option two

next:
- next question
- go next
- move next
- continue
- skip to next

previous:
- previous question
- go back
- back question
- last question

read:
- read question
- repeat question
- say question again
- read again

review:
- open review
- go to review
- review answers
- show review

submit:
- submit quiz
- finish quiz
- go to submit

confirm submit:
- confirm submit
- final submit
- yes submit
```

Keep command phrases short and distinct.

Prefer:

```text
"Option A"
"Next question"
"Read question"
"Submit quiz"
"Confirm submit"
```

Avoid depending only on:

```text
"A"
"B"
"next"
"read"
"submit"
```

Single-letter and single-word commands can be supported, but should have lower confidence and may require context.

---

## Fuzzy Matching Requirements

Implement a fuzzy matcher using one of:

- existing project package
- a small local Levenshtein implementation
- Jaro-Winkler if already available

Do not add a heavy dependency unless necessary.

Required behavior:

```text
exact match -> high confidence
alias match -> high confidence
fuzzy match >= strict threshold -> execute if safe
fuzzy match in medium range -> ask confirmation
fuzzy match below medium -> fallback/not understood
```

Suggested thresholds:

```text
strict mode:
  execute >= 0.90
  confirm >= 0.75

normal mode:
  execute >= 0.85
  confirm >= 0.65

flexible mode:
  execute >= 0.78
  confirm >= 0.58
```

Risky command thresholds:

```text
risky execute >= 0.95 and exact/strong phrase required
risky confirm >= 0.85
otherwise not understood or ask safe clarification
```

---

## Cloud STT Fallback Requirements

Create `CloudSpeechService`.

The Flutter app should call backend:

```text
POST /api/voice/transcribe-command
```

Request fields:

```json
{
  "locale": "en-US",
  "screen": "quiz",
  "availableCommands": [
    "option a",
    "option b",
    "option c",
    "option d",
    "next question",
    "previous question",
    "read question",
    "submit quiz"
  ],
  "audioFormat": "m4a",
  "audio": "<multipart file or binary upload>"
}
```

Response fields:

```json
{
  "transcript": "option b",
  "confidence": 0.93,
  "provider": "google|azure|deepgram|openai",
  "language": "en",
  "durationMs": 1800
}
```

The client must still run the returned transcript through the same parser and safety policy.

Do not execute cloud result directly.

---

## Audio Recording Requirements

Add an audio buffer around listening.

Requirements:

- record short clips only
- suggested duration: 3-8 seconds
- stop recording when speech result ends or timeout occurs
- only upload when fallback is needed
- delete temporary audio after processing
- handle permission errors gracefully
- handle no internet gracefully

Suggested package:

```yaml
record: latest_stable_version
connectivity_plus: latest_stable_version
permission_handler: latest_stable_version
```

Do not update package versions blindly if the project has compatibility constraints. Check current Flutter SDK and dependency versions first.

---

## Voice Calibration Requirements

Add a calibration flow if it does not already exist.

Calibration should ask user to say:

```text
Option A
Option B
Option C
Option D
Next question
Read question
True
False
Submit quiz
```

Store mapping:

```json
{
  "expectedPhrase": "option b",
  "heardText": "opson bee",
  "normalizedHeardText": "option b",
  "intent": "select_option",
  "value": "B"
}
```

Use calibration results as high-priority aliases for that user.

Do not calibrate or auto-learn final submit without safe confirmation.

---

## User Learning Requirements

When app asks:

```text
Did you mean Option B?
```

and user confirms:

```text
Yes
```

save correction:

```text
raw heard text -> intended command
```

Rules:

- store per user/device
- include screen context
- do not learn from risky command unless explicitly safe
- allow user to clear learned voice corrections in settings
- cap correction list size to avoid pollution
- track correction usage count
- prefer recent successful corrections

---

## Voice Settings Requirements

Settings should support:

- selected speech locale
- auto-listen on screen open
- command sensitivity: strict / normal / flexible
- enable/disable cloud fallback
- show/hide heard text
- show debug confidence
- TTS speed
- TTS pitch
- TTS language
- clear learned corrections
- run voice calibration again

If cloud fallback is disabled, the app must not upload audio.

---

## Audio Quality / Mic Requirements

Add basic audio quality feedback if feasible:

- too quiet warning
- noisy environment warning
- suggest moving closer
- suggest headset/Bluetooth mic
- show simple mic level indicator if supported

Do not promise long-distance recognition. Phone hardware has limits.

UX messages:

```text
"I can't hear you clearly. Please move closer or use a headset."
"Background noise is high. Tap the mic and speak closer."
```

---

## Analytics Requirements

Extend analytics with:

- raw transcript
- normalized transcript
- detected intent
- command confidence
- source: native/cloud/correction
- screen context
- success/failure
- fallback used
- confirmation shown
- confirmation accepted/rejected
- locale
- selected sensitivity
- unknown command count
- risky command blocked count
- cloud latency
- native success rate
- cloud success rate

Never log sensitive personal audio permanently unless explicitly required and consented. Prefer transcript and metrics.

---

## Error Handling Requirements

Handle:

- mic permission denied
- speech unavailable
- unsupported locale
- no internet for fallback
- cloud timeout
- backend error
- empty transcript
- low confidence result
- TTS engine unavailable
- app lifecycle pause/resume
- user interrupts speaking by tapping mic

The app must fail gracefully with user-friendly TTS/text feedback.

---

## Testing Requirements

Add unit tests for:

### Normalizer

Test examples:

```text
option bee -> option b
of shun b -> option b
opson see -> option c
tree -> three
fals -> false
question five -> question 5
```

### Parser

Test:

```text
option a -> select option A
answer bee -> select option B
next question -> next
previous question -> previous
read question -> read
open review -> review
submit quiz -> submitQuiz
confirm submit -> confirmSubmit
question five -> jumpToQuestion(5)
```

### Fuzzy Matcher

Test:

```text
opton b -> option b
nex question -> next question
reed question -> read question
revue answers -> review
```

### Safety Policy

Test:

```text
weak submit match must not execute
confirm submit requires strong confidence
reset answers cannot be learned automatically
normal navigation command can be fuzzy executed
```

### Learning

Test:

```text
confirmed correction is saved
correction is applied next time
risky correction is rejected
clear corrections works
```

### Cloud Fallback

Mock cloud service and test:

```text
native fails -> cloud called
native succeeds -> cloud not called
cloud disabled -> cloud not called
no internet -> cloud not called
cloud transcript goes through parser
```

### Controller

Test:

```text
high confidence safe command executes
medium confidence asks confirmation
low confidence triggers fallback
unknown command gives help/not understood
pause stops TTS/listening
resume restarts listening
```

---

## Manual QA Test Matrix

Test on real devices if possible.

### Accents

- African English speaker
- Indian English speaker
- UK English speaker
- US English speaker
- non-native English speaker
- fast speaker
- slow speaker

### Environments

- quiet room
- noisy room
- phone 0.5 meter away
- phone 1 meter away
- phone 2 meters away
- headset mic
- Bluetooth mic

### Screens

- quiz screen
- review screen
- settings screen
- loading screen
- result screen

### Commands

- option A/B/C/D
- true/false
- multi-select
- next/previous
- repeat/read
- explain
- flag
- question number jump
- open review
- unanswered
- flagged
- submit quiz
- confirm submit
- cancel submit
- help
- pause/resume

---

## Acceptance Criteria

The implementation is acceptable only if:

1. Existing voice features still work.
2. Commands are parsed through normalizer + parser + confidence + safety policy.
3. Screen-aware command context is implemented.
4. Fuzzy matching is implemented and tested.
5. Risky commands are protected.
6. User correction learning works.
7. Voice calibration exists or is prepared with clean structure.
8. Cloud STT fallback interface exists.
9. No cloud secret key is stored in Flutter.
10. Fallback is only used when needed.
11. Voice settings expose sensitivity, locale, and fallback options.
12. Unit tests cover normalizer, parser, fuzzy matcher, safety, learning, and fallback.
13. App works offline with native recognition and parser.
14. App handles permission/network/STT errors gracefully.
15. Code is modular, readable, and maintainable.

---

# Step-by-Step Codex Prompts

Use these prompts one by one. Do not ask Codex to implement everything in one huge step.

---

## Prompt 1 — Audit Current Voice System

```text
Act as a senior Flutter developer. Audit the current voice assistant implementation.

Find all files related to:
- speech_to_text
- flutter_tts
- voice command parsing
- quiz voice mode
- review voice commands
- submit/confirm submit flow
- voice settings
- voice overlay
- voice analytics

Do not modify code yet.

Return:
1. Current architecture summary
2. Main voice-related files
3. Current command parsing flow
4. Current safety issues
5. Missing pieces for accent support
6. Recommended refactor plan with minimal breaking changes
```

---

## Prompt 2 — Create Voice Core Models

```text
Implement core voice models without changing existing behavior.

Create or update files under lib/voice/core:

- voice_intent.dart
- voice_command_context.dart
- voice_command_result.dart
- voice_confidence_level.dart
- voice_safety_policy.dart

Requirements:
- Add typed enum for all supported intents.
- Add screen context enum.
- Add command decision enum: execute, askConfirmation, fallbackToCloud, notUnderstood, ignored.
- Add VoiceIntent model with type, value, number, confidence, isRisky, rawText, normalizedText, source.
- Add safety policy helpers to identify risky commands.
- Keep code null-safe and testable.
- Do not wire into UI yet.
```

---

## Prompt 3 — Implement Transcript Normalizer

```text
Implement VoiceTextNormalizer.

Create lib/voice/parsing/voice_text_normalizer.dart.

Requirements:
- lowercase
- trim
- remove punctuation
- collapse whitespace
- normalize option letters
- normalize common STT/accent mistakes
- normalize number words to digits where useful
- avoid dangerous over-normalization for submit/final submit

Handle examples:
- option bee -> option b
- option be -> option b
- of shun b -> option b
- opson bee -> option b
- answer sea -> answer c
- answer see -> answer c
- option dee -> option d
- tree -> three or 3 depending parser need
- free -> three or 3 depending parser need
- fals -> false
- falls -> false
- kweschen -> question
- nex -> next
- question five -> question 5

Add unit tests for all examples.
```

---

## Prompt 4 — Implement Command Aliases

```text
Create lib/voice/parsing/voice_command_aliases.dart.

Build a central command alias registry.

Requirements:
- Support quiz, review, settings, loading/session, and global commands.
- Include aliases for:
  option A/B/C/D
  first/second/third/fourth option
  true/false
  next/previous/skip
  read/repeat
  explain
  flag/bookmark
  open review
  unanswered
  flagged
  question number jump
  submit quiz
  confirm submit
  cancel submit
  start quiz/test
  retry
  back
  help
  status
  pause/resume
  timed mode on/off
  increase/decrease questions
  set questions to N
- Each alias must map to a VoiceIntent.
- Keep risky commands marked.
- Do not execute anything yet.
```

---

## Prompt 5 — Implement Fuzzy Matcher

```text
Implement a lightweight fuzzy matcher.

Create lib/voice/parsing/fuzzy_matcher.dart.

Requirements:
- Use local Levenshtein similarity or existing dependency if already present.
- Return best match with score.
- Keep implementation small and deterministic.
- Add tests for:
  opton b -> option b
  nex question -> next question
  reed question -> read question
  revue answers -> review answers
  confarm submit -> confirm submit
- Do not add heavy packages unless necessary.
```

---

## Prompt 6 — Implement Screen-Aware Command Parser

```text
Implement VoiceCommandParser.

Create lib/voice/parsing/voice_command_parser.dart.

Requirements:
- Input: raw text, VoiceScreenContext, command sensitivity, learned corrections.
- Steps:
  1. normalize raw text
  2. check learned corrections for this user/context
  3. exact alias match
  4. pattern match for question number jump
  5. pattern match for set questions to N
  6. fuzzy match against allowed commands for current screen only
  7. return VoiceCommandResult

Sensitivity thresholds:
strict:
  execute >= 0.90
  confirm >= 0.75
normal:
  execute >= 0.85
  confirm >= 0.65
flexible:
  execute >= 0.78
  confirm >= 0.58

Risky command rules:
- no weak fuzzy direct execution
- require strong exact/alias or high-confidence confirmation
- final submit must ask confirmation unless user already explicitly said confirm submit on review screen

Add unit tests for all common commands.
```

---

## Prompt 7 — Implement Learning Service

```text
Implement VoiceLearningService.

Requirements:
- Store user-specific learned corrections locally.
- Use SharedPreferences or the project’s existing local storage solution.
- Correction fields:
  rawHeardText
  normalizedText
  intentType
  value
  number
  screenContext
  createdAt
  lastUsedAt
  useCount
  isRisky
- Do not save risky command corrections by default.
- Cap corrections to a safe max count, e.g. 200.
- Add methods:
  getCorrections(context)
  saveCorrection(...)
  findCorrection(...)
  clearCorrections()
- Add unit tests where possible.
```

---

## Prompt 8 — Implement Cloud Speech Service Interface

```text
Implement cloud fallback interface.

Create lib/voice/recognition/cloud_speech_service.dart.

Requirements:
- No real provider key in Flutter.
- Call backend endpoint only.
- Endpoint should be configurable.
- Use multipart audio upload or existing app API client.
- Request must include:
  locale
  screen context
  available commands
  audio file
- Response:
  transcript
  confidence
  provider
  language
  durationMs
- Do not execute transcript directly.
- Return a SpeechRecognitionResult object.
- Handle timeout, no internet, server error, invalid response.
- Add mockable interface for tests.
```

---

## Prompt 9 — Implement Audio Recorder Buffer

```text
Implement VoiceAudioRecorder.

Requirements:
- Use record package if not already available.
- Request/check mic permission properly.
- Start recording when listening starts.
- Stop recording when speech recognition ends or timeout occurs.
- Store temporary audio file.
- Only send to cloud if fallback is needed.
- Delete temporary file after fallback or when no longer needed.
- Handle permission denied and recorder errors gracefully.
- Do not break existing speech_to_text listening.
```

---

## Prompt 10 — Refactor Native Speech Service

```text
Refactor native speech_to_text usage into NativeSpeechService.

Requirements:
- Support localeId from settings.
- Expose available locales.
- Support partial results.
- Provide confidence if available.
- Provide raw transcript.
- Handle speech unavailable, permission denied, timeout, cancel.
- Keep existing voice behavior working.
- Do not remove current UI features.
```

---

## Prompt 11 — Implement Voice Assistant Controller Pipeline

```text
Implement or refactor VoiceAssistantController to use the full pipeline.

Pipeline:
1. Start audio recorder
2. Start native speech_to_text
3. Receive transcript
4. Stop recorder
5. Parse transcript using VoiceCommandParser
6. If execute -> execute mapped app action
7. If askConfirmation -> show/speak “Did you mean ...?”
8. If fallbackToCloud and fallback enabled/internet available -> send audio to cloud
9. Parse cloud transcript
10. Execute/confirm/not understood
11. Save correction only after user confirms
12. Log analytics

Requirements:
- Preserve existing commands.
- Integrate with existing quiz/review/settings screens.
- Do not execute risky commands without confirmation.
- Handle pause/resume.
- Handle TTS interruption.
- Handle mic tap to interrupt/listen.
```

---

## Prompt 12 — Add Voice Calibration Flow

```text
Add voice calibration flow.

Requirements:
- Add screen or dialog for voice setup.
- Ask user to say:
  Option A
  Option B
  Option C
  Option D
  Next question
  Read question
  True
  False
  Submit quiz
- For each phrase:
  listen
  normalize
  map to expected intent
  save as correction/alias if safe
- Do not auto-learn final submit.
- Add setting to rerun calibration.
- Add skip option.
```

---

## Prompt 13 — Upgrade Voice Settings

```text
Upgrade voice settings.

Add settings for:
- selected speech locale
- command sensitivity: strict, normal, flexible
- enable cloud fallback
- show heard text
- show debug confidence
- auto-listen on screen open
- TTS speed
- TTS pitch
- TTS language
- clear learned corrections
- run voice calibration

Requirements:
- Use available locales from NativeSpeechService.
- If selected locale unavailable, fall back to system default.
- If cloud fallback disabled, never upload audio.
```

---

## Prompt 14 — Add Audio Quality Feedback

```text
Add basic audio quality feedback.

Requirements:
- If recorder/package supports amplitude, show mic level.
- Detect too quiet input and show/speak a helpful message.
- Detect repeated unknown commands and suggest moving closer/headset.
- Do not promise long-distance recognition.
- Keep UI simple and non-intrusive.
```

---

## Prompt 15 — Add Analytics Logging

```text
Extend voice analytics.

Log:
- screen context
- raw transcript
- normalized transcript
- intent
- confidence
- source: native/cloud/correction
- decision
- fallback used
- confirmation shown
- confirmation accepted/rejected
- risky command blocked
- selected locale
- command sensitivity
- native/cloud latency
- error type if failed

Respect privacy:
- Do not permanently store raw audio unless explicit consent exists.
- Prefer metrics and transcript logs.
```

---

## Prompt 16 — Add Tests

```text
Add or update tests for the voice assistant.

Required test groups:
1. VoiceTextNormalizer tests
2. VoiceCommandParser tests
3. FuzzyMatcher tests
4. VoiceSafetyPolicy tests
5. VoiceLearningService tests
6. Cloud fallback mocked tests
7. VoiceAssistantController pipeline tests if architecture allows

Run tests and fix failures.

Do not skip tests for risky submit behavior.
```

---

## Prompt 17 — Manual QA Checklist

```text
Create a MANUAL_VOICE_QA.md file.

Include test scenarios for:
- African English accent
- Indian English accent
- US/UK English
- noisy room
- quiet room
- headset mic
- phone 1-2 meters away
- quiz screen commands
- review screen commands
- settings commands
- loading/session commands
- submit confirmation safety
- cloud fallback disabled
- cloud fallback enabled
- offline mode
- permission denied
- TTS interruption
```

---

## Prompt 18 — Final Review And Cleanup

```text
Review the complete implementation.

Check:
- no API secrets in Flutter
- no risky command direct execution from weak fuzzy match
- no cloud upload when disabled
- no broken existing voice features
- no duplicate parser logic scattered across screens
- all new files are formatted
- tests pass
- manual QA doc exists
- code is readable and modular

Then provide:
1. Summary of changes
2. Files changed
3. How to configure backend endpoint
4. How to test
5. Known limitations
6. Next recommended improvements
```

---

# Implementation Notes For Codex

- Work incrementally.
- Prefer small PR-sized changes.
- Do not rewrite the entire app unless necessary.
- Keep existing UI and state management style.
- If the project uses GetX, follow GetX.
- If the project uses Bloc, follow Bloc.
- If the project uses Provider/Riverpod, follow that.
- Avoid introducing a second state management pattern.
- Prefer dependency injection for services so tests can mock native/cloud STT.
- Keep voice parsing independent from UI.
- Keep cloud fallback optional.
- Never store secret keys in client code.
- Always protect final submission.

---

# Definition Of Done

The voice assistant is considered production-ready for this phase when:

- Native STT works as before.
- Accent-related transcript mistakes are normalized.
- Fuzzy parser catches common mistakes.
- User can choose locale/accent where supported.
- User can calibrate voice.
- User corrections are learned safely.
- Low-confidence commands ask confirmation.
- Cloud fallback is integrated through backend interface.
- Risky commands are protected.
- App works offline.
- App handles mic/network/STT errors gracefully.
- Tests cover the critical voice logic.
- Manual QA guide exists.