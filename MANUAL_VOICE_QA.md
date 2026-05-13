# Manual Voice QA Checklist

## Accents

- [ ] African English: option A/B/C/D, next, read question, submit quiz.
- [ ] Indian English: option A/B/C/D, true/false, question number jump.
- [ ] UK English: next/previous, flag, open review, confirm/cancel submit.
- [ ] US English: quiz, review, settings, and session commands.
- [ ] Non-native English: repeat/read, help, pause/resume, retry after unknown.

## Environment

- [ ] Quiet room: native recognition works without cloud fallback.
- [ ] Noisy room: unknown commands show helpful retry guidance.
- [ ] Headset mic: commands remain accurate and TTS does not block listening.
- [ ] Bluetooth mic: permissions, listening, and command execution work.
- [ ] Phone 0.5m away: option selection and navigation commands work.
- [ ] Phone 1m away: repeated unknowns suggest moving closer or headset.
- [ ] Phone 2m away: app does not promise long-distance recognition.

## Quiz Screen

- [ ] Option A/B/C/D.
- [ ] True/false.
- [ ] Multi-select answers.
- [ ] Next/previous.
- [ ] Repeat/read question.
- [ ] Explain answer.
- [ ] Flag/bookmark.
- [ ] Question number jump.
- [ ] Open review.
- [ ] Help.
- [ ] Pause/resume.

## Review Screen

- [ ] Unanswered.
- [ ] Flagged.
- [ ] Question number jump.
- [ ] Read summary.
- [ ] Submit quiz.
- [ ] Confirm submit.
- [ ] Cancel submit.

## Settings Screen

- [ ] Start quiz.
- [ ] Timed mode on/off.
- [ ] Increase/decrease questions.
- [ ] Set questions to N.
- [ ] Change speech locale safely.
- [ ] Change command sensitivity.
- [ ] Clear learned corrections.

## Loading / Session Screen

- [ ] Start test.
- [ ] Retry.
- [ ] Cancel.
- [ ] Back.
- [ ] Help.
- [ ] Status.

## Fallback / Offline / Permission

- [ ] Cloud fallback off: no audio upload occurs.
- [ ] Cloud fallback on: native STT runs first; cloud runs only after local failure.
- [ ] Cloud transcript is parsed again before any action executes.
- [ ] Offline mode: app remains usable with native/local commands.
- [ ] Permission denied: app shows a helpful microphone permission message.

## TTS And Safety

- [ ] TTS interruption: stop/pause/quiet does not leave listening stuck.
- [ ] Risky submit safety: submit quiz asks for confirmation when needed.
- [ ] Final submit requires explicit confirmation.
- [ ] Weak fuzzy submit/reset/delete commands never execute directly.
