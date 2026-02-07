# Comprehensive PRD: Hands-Free First‑Aid Coach
**Version 3.0 — Extremely Detailed, Agent‑Executable Specification**  
**Hackathon MVP (16 hours) — Team of 4**

---

## Introduction / Overview

This product is a **hands‑free first‑aid coaching system** that runs on a smartphone paired with Meta Ray‑Ban smart glasses.  
It guides an untrained bystander through **critical first‑aid actions** using voice instructions, visual prompts, timers, and metronomes.

The system observes the scene through the camera, confirms facts with the user, and activates **strictly predefined medical playbooks**.  
It does **not** diagnose, predict outcomes, or give medical advice beyond first‑aid procedures.

**Supported scenarios (MVP, locked):**
1. Adult CPR  
2. Severe external bleeding  
3. Adult choking  

Anything outside this scope results in:
- Immediate instruction to call emergency services
- Clarifying questions
- No procedural guidance

---

## Goals

1. Reduce bystander paralysis during emergencies
2. Ensure correct pacing and sequencing of first‑aid actions
3. Prevent unsafe improvisation by locking behavior to playbooks
4. Enable hands‑free operation via smart glasses
5. Maintain traceability and replayability of all actions

---

## Non‑Goals (Out of Scope)

- Diagnosis or medical judgment
- Pediatric instructions
- Medication guidance
- Offline usage
- Long‑term medical tracking
- AI improvisation or reasoning outside playbooks
- Expansion beyond the 3 supported scenarios

---

## User Stories

1. **As a bystander**, I want spoken instructions so I don’t have to look at my phone.
2. **As a bystander**, I want the app to keep tempo during CPR.
3. **As a bystander**, I want the app to ask questions before assuming what’s happening.
4. **As a safety reviewer**, I want all actions logged and replayable.
5. **As a hackathon judge**, I want to see clear scope control and safety guardrails.

---

## Global AI Agent Rules (Non‑Negotiable)

1. **No assumptions**
   - If any required fact is unknown → ask a yes/no question.
   - Never infer breathing state, consciousness, or cause.

2. **Playbook‑only execution**
   - The agent may only execute steps defined in this PRD.
   - No paraphrasing of medical steps.

3. **Scope lock**
   - Only CPR, bleeding, choking.
   - Any other situation → emergency call + clarification.

4. **Tool allowlist**
   - `speak(text)`
   - `show_ui(card)`
   - `start_timer(label, seconds)`
   - `stop_timer(label)`
   - `start_metronome(bpm)`
   - `stop_metronome()`
   - `log_event(event)`

5. **Uncertainty rule**
   - If uncertain → STOP → ASK USER → REFER TO PRD

---

## System Architecture Overview

**Components**
- Mobile App (iOS)
- Smart Glasses (audio + display)
- Backend API
- Vision‑Language Model (VLM)
- Agent FSM (policy layer)

---

## End‑to‑End Execution Flow (Every Step)

### Phase 0 — App Launch
1. User opens app
2. App initializes local state
3. App checks permissions:
   - Camera
   - Microphone
   - Bluetooth
4. If any permission denied → show blocking modal

### Phase 1 — Session Start
5. User taps “Start Session”
6. App creates session ID
7. App attempts glasses connection
8. If glasses unavailable after 30s → fallback to phone audio
9. Live preview UI displayed

### Phase 2 — Frame Capture
10. Capture frame every 2 seconds
11. Apply face/body blur
12. Attach timestamp + session ID
13. Send frame to backend

### Phase 3 — Perception
14. VLM processes frame
15. Outputs structured JSON:
```json
{
  "candidate_scenario": "CPR | BLEEDING | CHOKING | NONE",
  "confidence": 0.0,
  "scene_cues": [],
  "risk_flags": []
}
```

### Phase 4 — Policy Decision
16. FSM checks confidence threshold
17. If confidence < threshold → ask clarification
18. If confidence >= threshold → proceed
19. If scenario = NONE → emergency call + question

### Phase 5 — Clarification Loop
20. Agent asks yes/no question
21. Waits for user response
22. Logs response
23. Re‑evaluates FSM

### Phase 6 — Playbook Activation
24. Agent announces scenario
25. Agent instructs emergency call
26. Agent executes scenario‑specific steps

### Phase 7 — Continuous Monitoring
27. Continue frame capture
28. Monitor for state change
29. If state changes → pause playbook
30. Ask clarification
31. Resume or terminate

### Phase 8 — Session End
32. User taps “End Session”
33. Stop timers and metronomes
34. Save session log
35. Enable replay mode

---

## Scenario Playbooks (Step‑by‑Step)

### CPR — Adult

**Entry Requirements**
1. User confirms person is unresponsive
2. User confirms person is not breathing normally

**Execution**
3. Speak: “Call emergency services now.”
4. Speak: “Place hands in center of chest.”
5. Start metronome at 110 BPM
6. Speak compression count every 10 beats
7. Start 120‑second timer for rescuer switch
8. On timer end → speak “Switch rescuers if possible.”
9. Repeat until session ends

---

### Severe External Bleeding

**Entry Requirements**
1. User confirms visible heavy bleeding

**Execution**
2. Speak: “Call emergency services now.”
3. Show UI: “Apply firm pressure.”
4. Start 120‑second pressure timer
5. At timer end → speak “Check bleeding.”
6. If bleeding continues → restart timer

---

### Adult Choking

**Entry Requirements**
1. User confirms inability to speak or cough

**Execution**
2. Speak: “Call emergency services now.”
3. Show UI: “Perform abdominal thrusts.”
4. Count thrusts aloud
5. Monitor for recovery or collapse
6. If collapse → transition to CPR flow

---

## Detailed Team Roles & Parallelization

### Role A — Mobile / UI
- Permission handling
- Session UI
- Timers & metronome
- Audio routing
- Replay UI

### Role B — Backend
- Session management
- Frame ingestion
- Logging
- Replay storage

### Role C — ML / Vision
- VLM prompt
- Scene cue extraction
- Confidence scoring

### Role D — Agent / Policy
- FSM logic
- Clarification logic
- Tool validation
- Safety enforcement

**All roles can begin immediately.**
Only shared dependency: JSON schemas.

---

## Logging & Replay

Each session logs:
- Timestamped agent actions
- User responses
- Tool calls
- Scenario transitions

Replay shows:
1. Video frames
2. Spoken instructions
3. Timers/metronomes
4. Decision points

---

## Acceptance Criteria

- Agent never proceeds without confirmation
- No action outside playbooks
- Emergency call always instructed
- Timers/metronome accurate ±1%
- Replay matches live session

---

## Final Rule

If **anything** is unclear at runtime:

> **STOP → ASK USER → REFER BACK TO THIS PRD**
