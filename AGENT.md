# AGENT.md — Adaptive Voice Command Learning for Flutter Quiz Assistant

## Role

You are a senior Flutter engineer improving an existing quiz/exam app voice assistant.

The assistant already has a working flow:

```text
MCQ screen opens
→ assistant reads the question first
→ after TTS finishes, assistant listens
→ user speaks a command
→ assistant executes the command
```

Do not redesign this flow. Your task is to make the assistant smarter, more forgiving, and more efficient at understanding user commands, spelling mistakes, STT mistakes, accent variants, and learned user-specific phrases.

This phase is **no-cloud / no-paid-AI**. Use the existing native `speech_to_text`, parser, normalizer, fuzzy matcher, learning service, and TTS flow.

---

## Main Goal

Add **Adaptive Voice Command Understanding**.

The assistant should understand:

```text
next
go next
go nest
nex question
read
reed question
repeat
flag
flug
bookmark
select c
select see
select sea
syllet see
sillect c
option si
option see
option sea
```

and map them to the correct app command when safe.

If the assistant is unsure, it should ask a simple confirmation:

```text
Did you mean Select C?
```

If the user says:

```text
yes
```

then the assistant should execute the suggested command and save the correction for future use.

Next time the same phrase should execute the correct command directly, unless it is risky or conflicting.

---

## Non-Negotiable Rules

- Do not rewrite the whole assistant.
- Do not redesign MCQ/review/settings UI.
- Do not change the read-first-then-listen workflow.
- Do not execute raw STT text directly.
- Do not execute unstable partial STT text.
- Do not weaken submit/final-submit safety.
- Do not auto-learn risky commands.
- Do not save conflicting option corrections.
- Direct option grammar must always beat learned corrections.
- If text clearly sounds like Option C, never save it as Option A.
- If text clearly sounds like Option B, never save it as Option D.
- Prefer asking retry/confirmation over executing the wrong command.
- Keep the app working offline.
- Keep changes small and testable.

---

## Correct Command Pipeline

All command recognition should follow this pipeline:

```text
raw final STT transcript
→ canonical normalizer
→ direct option grammar
→ exact safe alias match
→ learned correction if safe and non-conflicting
→ fuzzy / phonetic match
→ ambiguity check
→ confidence decision
→ execute / ask confirmation / ask retry
→ save safe correction only after yes
```

Partial STT results should update heard text/debug UI only.

---

## Parser Priority

Use this order:

1. Normalize text.
2. Direct option grammar.
3. True/False grammar.
4. Number/question grammar.
5. Exact safe alias match.
6. Safe learned correction.
7. Fuzzy/phonetic match.
8. Confirmation or retry.

Important:

```text
Direct option grammar > learned correction
Exact safe alias > STT confidence
Risky command safety > everything
```

---

## Exact Safe Command Rule

If the transcript exactly matches a safe command alias, execute it with high local parser confidence, even if STT confidence is low or null.

Safe examples:

```text
flag
flag question
bookmark
next
next question
read
read question
repeat
explain
help
option a
option b
option c
option d
select c
choose c
```

Risky commands are different:

```text
submit
final submit
reset
delete
exit
```

Risky commands must still go through stricter safety rules.

---

## Required Alias Expansion

Add or verify aliases for these command groups.

### Next Question

```text
next
next question
go next
go nest
move next
continue
nex
nex question
```

### Previous Question

```text
previous
previous question
back
go back
last question
prev
preveous
```

### Read / Repeat

```text
read
read question
reed
reed question
repeat
repeat question
say again
read again
```

### Explain

```text
explain
explain answer
explanation
show explanation
```

### Flag / Bookmark

```text
flag
flag question
flug
flak
flagged
bookmark
bookmark question
mark
mark question
```

### Review

```text
review
open review
go review
go to review
review answers
```

### Option A

```text
a
option a
option ay
option hey
option eh
answer a
select a
choose a
first
first option
option one
```

### Option B

```text
b
option b
option bee
option be
option bi
answer b
select b
choose b
second
second option
option two
```

### Option C

```text
c
option c
option see
option sea
option si
option she
answer c
answer see
answer sea
answer si
select c
select see
select sea
select si
syllet see
sillect c
slect c
sellect c
choose c
choose see
choose sea
third
third option
option three
```

### Option D

```text
d
option d
option dee
option de
option the
answer d
select d
choose d
fourth
fourth option
option four
```

### True / False

```text
true
tru
through
false
fals
falls
```

### Question Jump

```text
question five
question 5
go to question five
go to question 5
number five
number 5
```

---

## Normalization Requirements

Normalize common spelling/STT/accent mistakes:

```text
go nest -> go next
nex -> next
queshan / kweshen / queschen / kweschen -> question
reed -> read
flug / flak / flagged -> flag
syllet / sillect / slect / sellect -> select
fals / falls -> false
tru / through -> true
```

Context-aware option normalization:

```text
option see / option sea / option si -> option c
answer see / answer sea / answer si -> answer c
select see / select sea / select si -> select c
choose see / choose sea / choose si -> choose c

option bee / option be / option bi -> option b
answer bee / answer be / answer bi -> answer b
select bee / select be / select bi -> select b

option dee / option de / option the -> option d
answer dee / answer de -> answer d
select dee / select de -> select d
```

Do not globally convert every word `see` to `c`; only convert it in option/select/choose/answer contexts.

---

## Suggestion and Confirmation Flow

If the parser is not confident enough to execute but finds a likely safe command, ask:

```text
Did you mean Select C?
```

or

```text
Did you mean Next question?
```

If user says yes:

```text
yes
yeah
yep
correct
right
that's right
```

then:

1. Execute the suggested command if safe.
2. Save learned correction if non-risky and non-conflicting.
3. Log the learned correction.

If user says no:

```text
no
nope
wrong
cancel
```

then:

1. Do not execute.
2. Ask the user to repeat.

Do not ask confirmation forever. Use a pending suggestion state and clear it after yes/no/timeout.

---

## Learned Correction Rules

Save fields:

```text
rawHeardText
normalizedText
screenContext
intentType
value
number
confidence
matchSource
createdAt
lastUsedAt
useCount
isRisky
```

Rules:

- Store per user/device/profile if the project supports it.
- Keep corrections screen-aware.
- Cap total corrections, e.g. 200.
- Prefer recent successful corrections.
- Increment use count when applied.
- Add clear corrections option if not already present.
- Do not learn final-submit.
- Do not learn reset/delete/exit/destructive actions.
- Do not save conflicting option mappings.

---

## Conflict Detection

Reject or clean corrections like:

```text
option si -> Option A
option see -> Option A
option sea -> Option A
answer see -> Option A
answer sea -> Option A
select see -> Option A
syllet see -> Option A
sillect c -> Option A
```

General rule:

```text
C-like heard text cannot map to A/B/D.
B-like heard text cannot map to A/C/D unless direct grammar confirms.
D-like heard text cannot map to A/B/C unless direct grammar confirms.
```

Direct grammar always wins over learned correction.

---

## Fuzzy Matching Rules

Use fuzzy matching only after direct/alias/learning checks.

Rules:

- Keep matcher lightweight.
- If top match score is high and not ambiguous, execute safe command.
- If medium confidence, ask confirmation.
- If low confidence, ask retry.
- If top two matches are too close, do not execute; ask clarification/retry.
- Single-letter commands should only execute in safe screen contexts.
- Risky commands need stricter thresholds and should not be learned automatically.

---

## Screen-Aware Behavior

### MCQ Screen

Allowed adaptive commands:

```text
option/select/choose A-D
true/false
next
previous/back
read/repeat
explain
flag/bookmark
open review
submit quiz
question number jump
```

### Review Screen

Allowed adaptive commands:

```text
unanswered
flagged
question number jump
read summary
submit quiz
back
help
```

### Settings Screen

Allowed adaptive commands:

```text
start quiz
timed mode on/off
increase/decrease questions
set questions to N
help
back
```

Do not match commands that are irrelevant to the current screen.

---

## Submit Safety

Do not weaken submit safety.

Rules:

- MCQ screen: `submit` / `submit quiz` opens review only.
- Review screen: strong direct submit may final-submit if this is current product behavior.
- Weak/fuzzy/ambiguous/learned-only submit must not final-submit directly.
- If confirmation is needed, ask simple yes/no:
  - “Do you want to submit your quiz?”
- Do not require the phrase `confirm submit`.
- Do not auto-learn submit/final submit.

---

## Debug Logging

Add or keep debug logs for:

```text
raw transcript
normalized transcript
screen context
match source: direct / exactAlias / learned / fuzzy / suggestion
confidence
suggested command
learned correction saved/ignored
conflict reason
reject reason
STT confidence
```

Do not log raw audio.

---

## Tests Required

Add or update tests for:

```text
next -> next question
go next -> next question
go nest -> next question
nex question -> next question

read -> read question
reed question -> read question
repeat -> read question

flag -> flag question
flug -> flag question
flak -> flag question
bookmark -> flag question

select c -> Option C
select see -> Option C
select sea -> Option C
syllet see -> Select C suggestion
sillect c -> Option C
option si -> Option C
option see -> Option C
option sea -> Option C

user confirms syllet see -> saved correction
next time syllet see -> Option C
bad correction syllet see -> Option A is ignored
direct option grammar beats learned correction

exact safe alias with low STT confidence still executes
weak submit fuzzy match does not execute
risky command is not auto-learned
```

---

## Low-Context Rules For Codex

- Do not re-audit unless explicitly asked.
- Work only on files listed in the prompt.
- Do not scan unrelated files.
- Make the smallest safe change.
- Do not rewrite screens.
- Preserve existing read-first-then-listen flow.
- Do not change submit behavior except preserving safety.
- Run `dart format` on changed files.
- Run `flutter analyze`.
- Run targeted voice tests if available.
- Stop after the requested task.

---

## Definition Of Done

This task is complete when:

- Common spelling/accent mistakes map to correct commands.
- Exact safe commands execute even if STT confidence is low.
- `go nest` executes Next question.
- `flug` executes Flag.
- `syllet see` can be suggested as Select C.
- If user says yes, the correction is saved.
- Next time the learned phrase executes the correct command.
- Bad learned corrections are rejected/cleaned.
- Submit/final-submit safety is preserved.
- Voice tests pass.
- `flutter analyze` passes.
