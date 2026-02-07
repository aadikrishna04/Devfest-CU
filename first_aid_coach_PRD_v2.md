# PRD — Hands-Free First-Aid Coach v2 (Dedalus Orchestration)
**Hackathon MVP (16 hours) — Team of 4**

## 0) TL;DR
A companion app turns Meta Ray-Ban glasses into a hands-free "first-aid coach." The phone captures POV video + user voice, sends to cloud (Modal), where **Dedalus orchestrates three AI systems**: a **VLM** (GPT-4o vision) analyzes scenes, **PersonaPlex** handles natural voice conversation, and a **coordinator agent** (Claude) makes decisions and triggers tools (metronome, timers, audio). **MediaPipe** blurs faces for privacy. Everything is traced via **Langfuse** for observability and demo replay.

---

## 1) Product Summary

### 1.1 One-liner
**"Point-of-care first-aid guidance in your ear, triggered by what you're seeing, with timers and rhythm assistance."**

### 1.2 Primary outcome
Help bystanders **avoid further harm** and **take immediate, safe actions** while **EMS is on the way**.

### 1.3 MVP scenarios (strictly 3)
1) **CPR assist** (unresponsive + not breathing normally)  
2) **Severe external bleeding**  
3) **Adult choking** (exclude infants/children for MVP)

### 1.4 Non-goals (explicitly out of scope)
- Diagnosis ("heart attack vs seizure"), medical advice beyond first-aid playbooks
- Pediatric emergencies, medication guidance (e.g., naloxone)
- On-device inference
- Continuous full-video streaming (we sample frames every 2-3s)
- Real-time PersonaPlex interruption (nice-to-have, not MVP-critical)

---

## 2) Target Users & Use Cases

### 2.1 Target user
A non-expert bystander (hackathon demo: teammate acting as bystander).

### 2.2 Core use cases
- User says "someone collapsed" → system confirms breathing → starts CPR metronome + 2-min switch timer
- User sees heavy bleeding → system prompts "is it still flowing heavily?" → pressure timer + escalation
- User says "they can't breathe" with throat gesture → confirm inability to speak/cough → abdominal thrust cadence

---

## 3) Safety & Ethics Requirements (MVP)

### 3.1 Hard safety rules
- Always show banner: **"Decision support only — call emergency services."**
- If high-risk flags: always begin with **"Call emergency services now."**
- Give instructions only if:
  - scenario confidence >= threshold **OR**
  - user confirms via voice/button prompts
- If uncertain: **ask clarifying questions** or stay silent (no guessing)
- Agent cannot invent actions:
  - medical steps come from fixed playbooks (in system prompts)
  - agent only **phrases** allowed steps and **executes** allowed tools

### 3.2 Privacy baseline
- **MediaPipe face blurring** on frames before cloud upload (best effort; toggleable for demo, default ON)
- No storing raw video; store only:
  - blurred frame thumbnails (optional)
  - event logs + timestamps
  - model outputs + tool calls

---

## 4) Technical Architecture

### 4.1 System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT (Phone App)                        │
│                                                               │
│  • Ray-Ban livestream OR phone camera fallback              │
│  • MediaPipe face blurring                                   │
│  • Audio capture from mic                                    │
│  • WebSocket connection to Modal backend                     │
│  • Local tool executors:                                     │
│    - Metronome playback (audio)                             │
│    - Timer countdown (UI + alerts)                          │
│    - UI updates (checklists, cards)                         │
│  • Audio routing to glasses speaker                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ WebSocket: frames + audio
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              MODAL BACKEND (Cloud Services)                  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         DEDALUS ORCHESTRATION ENGINE                  │  │
│  │                                                        │  │
│  │  DedalusRunner coordinates:                           │  │
│  │                                                        │  │
│  │  ┌─────────────────┐  ┌──────────────────┐           │  │
│  │  │   VLM Service   │  │  PersonaPlex     │           │  │
│  │  │  (GPT-4o Vision)│  │  (Voice Conv)    │           │  │
│  │  └────────┬────────┘  └────────┬─────────┘           │  │
│  │           │                     │                      │  │
│  │           └──────────┬──────────┘                      │  │
│  │                      ▼                                 │  │
│  │           ┌─────────────────────┐                     │  │
│  │           │ Coordinator Agent   │                     │  │
│  │           │  (Claude Sonnet 4)  │                     │  │
│  │           │                     │                     │  │
│  │           │  Reasons about:     │                     │  │
│  │           │  • Scene analysis   │                     │  │
│  │           │  • Conversation     │                     │  │
│  │           │  • Scenario state   │                     │  │
│  │           │  • Tool execution   │                     │  │
│  │           └──────────┬──────────┘                     │  │
│  │                      │                                 │  │
│  │                      ▼                                 │  │
│  │           ┌─────────────────────┐                     │  │
│  │           │  Tool Execution      │                     │  │
│  │           │  • analyze_scene     │                     │  │
│  │           │  • converse_user     │                     │  │
│  │           │  • start_metronome   │                     │  │
│  │           │  • start_timer       │                     │  │
│  │           │  • play_audio        │                     │  │
│  │           │  • show_ui           │                     │  │
│  │           │  • log_event         │                     │  │
│  │           └──────────────────────┘                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Supporting Services                           │  │
│  │  • WebSocket Gateway (FastAPI)                       │  │
│  │  • Session Store (Postgres/Supabase)                 │  │
│  │  • Event Logger (append-only)                        │  │
│  │  • VLM Worker (wraps GPT-4o vision API)             │  │
│  │  • PersonaPlex Worker (manages voice I/O)           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Observability (Langfuse)                      │  │
│  │  Traces:                                              │  │
│  │  • VLM calls + observations                          │  │
│  │  • PersonaPlex conversations                         │  │
│  │  • Coordinator reasoning                              │  │
│  │  • Tool calls + params                               │  │
│  │  • Safety checks                                      │  │
│  │  • Timestamps                                         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Core Components

#### A) Client (Phone App)
**Technology:** React Native or native iOS/Android  
**Responsibilities:**
- Capture video stream (Ray-Ban SDK or camera API)
- Apply MediaPipe face blur to frames
- Sample frames every 2-3 seconds, upload via WebSocket
- Capture user audio from mic
- Maintain WebSocket connection to backend
- Execute tool commands locally:
  - Metronome: play audio pulses at specified BPM
  - Timer: countdown with UI + alerts
  - UI: show cards, checklists, status
- Route audio to glasses speaker via Bluetooth

#### B) Dedalus Orchestration Engine
**Technology:** Dedalus SDK (Python), Modal for hosting  
**Responsibilities:**
- Coordinate multiple AI models (VLM + PersonaPlex + Coordinator)
- Execute tool calls in sequence or parallel
- Handle model handoffs with context preservation
- Stream responses back to client

**Models coordinated:**
1. **VLM (GPT-4o Vision)** - analyzes video frames
2. **PersonaPlex** - natural voice conversation
3. **Coordinator (Claude Sonnet 4)** - reasoning & decision-making

#### C) VLM Service
**Technology:** OpenAI GPT-4o Vision API  
**Responsibilities:**
- Receive blurred frame (base64 JPEG)
- Return structured observations:
  ```json
  {
    "observations": "person lying on ground, not moving, blood visible near head",
    "visible_cues": ["unresponsive", "blood", "pale skin"],
    "confidence": 0.85,
    "risk_flags": ["severe_bleeding", "unconscious"]
  }
  ```

#### D) PersonaPlex Service
**Technology:** NVIDIA PersonaPlex (hosted on GPU instance)  
**Responsibilities:**
- Accept user audio stream
- Maintain conversational context
- Respond with natural voice (configured as calm coach persona)
- Return both audio response + transcript

**Configuration:**
- Voice prompt: calm, clear, supportive tone
- Text prompt: first-aid coach persona with scene context

#### E) Coordinator Agent
**Technology:** Claude Sonnet 4 via Dedalus  
**Responsibilities:**
- Integrate observations from VLM
- Integrate conversation from PersonaPlex
- Maintain scenario state (NONE → CPR/BLEED/CHOKING → ACTIVE → END)
- Make tool execution decisions
- Enforce safety rules (embedded in system prompt)

#### F) Supporting Services
- **WebSocket Gateway:** bidirectional real-time communication
- **Session Store:** tracks session state, user confirmations
- **Event Logger:** append-only log for all decisions/actions
- **Langfuse Integration:** observability tracing

### 4.3 Data Flow (Live Session)

**Step 1: Frame Analysis (every 2-3 seconds)**
```
1. Client samples frame
2. Client blurs faces with MediaPipe
3. Client sends frame via WebSocket
4. Dedalus calls analyze_scene tool
5. VLM Service returns observations
6. Coordinator Agent receives observations
```

**Step 2: User Speaks**
```
1. User speaks into mic
2. Client sends audio chunk via WebSocket
3. Dedalus calls converse_with_user tool
4. PersonaPlex Service:
   - Receives audio + scene context + persona
   - Generates voice response
   - Returns audio + transcript
5. Audio streamed to client → glasses speaker
```

**Step 3: Decision & Tool Execution**
```
1. Coordinator Agent reasons:
   - Scene: "person unresponsive, not moving"
   - User confirmed: "not breathing normally"
   - Decision: CPR scenario, confidence 0.9
   
2. Agent executes tool sequence:
   - play_audio("Call emergency services now")
   - start_metronome(110)
   - start_timer("switch rescuer", 120)
   - show_ui({"type": "checklist", "items": [...]})
   - log_event({"scenario": "CPR", "confidence": 0.9})
   
3. Tools send commands to client via WebSocket
4. Client executes locally
```

**Step 4: Observability**
```
All calls logged to Langfuse:
- VLM observations with timestamps
- PersonaPlex audio + transcripts
- Coordinator reasoning traces
- Tool calls with parameters
- User confirmations
```

### 4.4 Tool Definitions

Tools available to Coordinator Agent via Dedalus:

```python
tools = [
    {
        "name": "analyze_scene",
        "description": "Analyze video frame to understand emergency situation",
        "parameters": {
            "frame_b64": "base64 encoded JPEG"
        }
    },
    {
        "name": "converse_with_user",
        "description": "Have voice conversation with user via PersonaPlex",
        "parameters": {
            "audio": "audio bytes",
            "scene_context": "current scene observations",
            "message": "what to communicate"
        }
    },
    {
        "name": "start_metronome",
        "description": "Start metronome for CPR timing",
        "parameters": {
            "bpm": "100-120 for CPR"
        }
    },
    {
        "name": "start_timer",
        "description": "Start countdown timer",
        "parameters": {
            "label": "timer name",
            "seconds": "duration"
        }
    },
    {
        "name": "stop_timer",
        "description": "Stop specific timer",
        "parameters": {
            "label": "timer name"
        }
    },
    {
        "name": "play_audio",
        "description": "Play audio instruction via glasses",
        "parameters": {
            "text": "text to speak (PersonaPlex converts to speech)"
        }
    },
    {
        "name": "show_ui",
        "description": "Display UI card on phone",
        "parameters": {
            "type": "checklist|banner|alert",
            "content": "UI content object"
        }
    },
    {
        "name": "log_event",
        "description": "Log important decision/action",
        "parameters": {
            "event_type": "scenario_detected|tool_called|user_confirmed",
            "data": "event data object"
        }
    }
]
```

### 4.5 Coordinator Agent System Prompt

```
You are coordinating a first-aid assistance system for a bystander helping 
someone in an emergency. You coordinate:

1. analyze_scene - VLM analyzes video to understand situation
2. converse_with_user - PersonaPlex has natural voice conversation
3. Tools: metronomes, timers, audio playback, UI updates

WORKFLOW:
- Every 2-3 seconds, analyze_scene provides observations
- User speaks naturally; use converse_with_user to respond
- Based on scene + conversation, determine scenario:
  * CPR (unresponsive + not breathing)
  * SEVERE_BLEEDING (heavy bleeding visible)
  * CHOKING (throat gesture + cannot speak/cough)
  * NONE (unclear or safe situation)

CRITICAL SAFETY RULES:
1. ALWAYS say "Call emergency services now" first for ANY scenario
2. Only activate scenario if:
   - Confidence >= 0.7 AND
   - User confirms key facts (e.g., "not breathing")
3. If uncertain: ask clarifying questions via converse_with_user
4. NEVER diagnose ("heart attack", "seizure", "stroke")
5. NEVER invent medical steps beyond playbooks below
6. Only execute tools that match the active scenario

PLAYBOOKS:

CPR SCENARIO:
Entry: unresponsive + not breathing normally (confirmed by user)
Actions:
1. play_audio("Call emergency services now")
2. start_metronome(110)
3. start_timer("switch_rescuer", 120)
4. show_ui({"type": "checklist", "items": [
     "Tilt head back, lift chin",
     "Place hands center of chest",
     "Press hard and fast, 2 inches deep",
     "Allow full chest recoil"
   ]})
5. converse_with_user: provide encouragement every 30s

SEVERE_BLEEDING SCENARIO:
Entry: heavy bleeding visible + user confirms "still flowing"
Actions:
1. play_audio("Call emergency services now")
2. show_ui({"type": "checklist", "items": [
     "Apply firm direct pressure",
     "Do not remove cloth if soaked",
     "Add more cloth on top"
   ]})
3. start_timer("pressure_check", 120)
4. converse_with_user: check if bleeding slowing after 2 min
5. If still severe: escalate instructions (tourniquet wording careful)

CHOKING SCENARIO (ADULT):
Entry: throat gesture + cannot speak/cough effectively
Actions:
1. play_audio("Call emergency services now")
2. show_ui({"type": "checklist", "items": [
     "Stand behind person",
     "Fist above navel, below ribs",
     "Quick upward thrusts"
   ]})
3. converse_with_user: count thrusts, check if cleared

TONE:
- Calm, clear, supportive
- Short sentences via play_audio (max 1-2 sentences)
- Use converse_with_user for:
  * Questions ("Are they breathing?")
  * Encouragement ("You're doing great")
  * Clarifications ("I need to confirm...")

LOGGING:
- log_event for all scenario changes, confirmations, tool calls
```

---

## 5) Team Breakdown (4 Roles)

### ROLE A: Mobile/Client Engineer

**Primary Deliverable:** Working client app with capture, local execution, and UI

**Responsibilities:**

1. **Video Capture**
   - Implement Ray-Ban livestream integration (Option A)
   - Fallback to phone camera capture (Option B)
   - Frame sampling (1 frame every 2-3 seconds)
   - JPEG encoding, base64 conversion

2. **MediaPipe Face Blurring**
   - Integrate MediaPipe face detection
   - Apply blur to detected faces
   - Toggleable (default ON, can disable for demo)

3. **Audio Capture**
   - Continuous mic recording
   - Audio chunking for streaming
   - Format: WebRTC-compatible or WAV chunks

4. **WebSocket Client**
   - Maintain persistent connection to Modal backend
   - Send: frames (base64 JPEG), audio chunks
   - Receive: tool commands (JSON)
   - Handle reconnection logic

5. **Local Tool Executors**
   - **Metronome:** play audio pulses at specified BPM
     - Use Audio API to play beep/click
     - Maintain accurate timing
   - **Timer:** countdown UI with alerts
     - Show remaining time
     - Alert when complete
   - **UI Updates:** render cards, checklists, banners
   - **Audio Playback:** route PersonaPlex audio to glasses speaker

6. **UI Screens**
   - Start Session screen
   - Live Session screen (preview, buttons, status)
   - Replay Timeline screen (event log viewer)

**Tech Stack:**
- React Native OR native iOS/Android
- MediaPipe SDK (mobile)
- WebSocket client library
- Bluetooth Audio API (for glasses routing)

**Integration Points:**
- **With Backend Engineer:** WebSocket protocol definition, message schemas
- **With Dedalus Engineer:** Tool command JSON formats
- **With Voice Engineer:** Audio format requirements for PersonaPlex

**Milestones:**
- T+4h: Live UI + dummy WebSocket connection working
- T+8h: Frame capture + MediaPipe blur + upload working
- T+10h: Audio capture + streaming working
- T+12h: Local tool executors (metronome, timer) functional
- T+14h: Audio routing to glasses working
- T+16h: Replay timeline screen minimally functional

---

### ROLE B: Backend/Infrastructure Engineer

**Primary Deliverable:** Modal services with WebSocket gateway, session management, VLM worker

**Responsibilities:**

1. **Modal Deployment Setup**
   - Configure Modal project
   - Set up GPU instances for PersonaPlex
   - Environment variables, secrets management
   - Deploy scripts

2. **WebSocket Gateway**
   - FastAPI WebSocket endpoint
   - Handle client connections
   - Route frames → Dedalus
   - Route audio → Dedalus
   - Send tool commands → client
   - Connection management, heartbeat

3. **Session Store**
   - Postgres or Supabase
   - Tables:
     - sessions (session_id, user_id, status, created_at)
     - events (session_id, timestamp, type, payload)
   - CRUD operations
   - Session state management

4. **Event Logger**
   - Append-only event log
   - Event types:
     - frame_analyzed
     - conversation_turn
     - scenario_detected
     - tool_called
     - user_confirmed
   - Fast writes, queryable for replay

5. **VLM Worker Service**
   - Wraps OpenAI GPT-4o Vision API
   - Accepts blurred frame (base64)
   - Returns structured JSON (observations, confidence, risk_flags)
   - Error handling, retries
   - Prompt engineering for consistent output

6. **PersonaPlex Worker Service**
   - Modal function to run PersonaPlex on GPU
   - Manages PersonaPlex instance lifecycle
   - Audio I/O handling
   - Voice + text prompt configuration
   - Returns audio + transcript

**Tech Stack:**
- Modal (Python)
- FastAPI (WebSocket server)
- Postgres/Supabase (session store)
- OpenAI SDK (VLM)
- PersonaPlex (NVIDIA, requires GPU)

**Integration Points:**
- **With Mobile Engineer:** WebSocket protocol, message schemas, latency SLA
- **With Dedalus Engineer:** Service APIs for VLM and PersonaPlex workers
- **With Voice Engineer:** PersonaPlex configuration, audio format specs

**Milestones:**
- T+3h: Modal project + WebSocket gateway echo test
- T+6h: Session store + event logging working
- T+8h: VLM worker returning structured observations
- T+10h: PersonaPlex worker deployed on GPU, basic audio I/O
- T+12h: End-to-end WebSocket streaming (client → backend → client)
- T+16h: All services stable, monitoring enabled

---

### ROLE C: Dedalus/Orchestration Engineer

**Primary Deliverable:** Dedalus orchestration engine with coordinator agent, tool definitions, model handoffs

**Responsibilities:**

1. **Dedalus SDK Integration**
   - Install and configure Dedalus SDK
   - Set up DedalusRunner
   - Configure model routing (GPT-4o, PersonaPlex, Claude)
   - API authentication (Dedalus, OpenAI, Anthropic)

2. **Tool Definitions**
   - Define all tools for coordinator agent:
     - analyze_scene
     - converse_with_user
     - start_metronome
     - start_timer
     - stop_timer
     - play_audio
     - show_ui
     - log_event
   - Implement tool functions (call VLM/PersonaPlex services, send WebSocket commands)
   - Input validation, error handling

3. **Coordinator Agent**
   - Write comprehensive system prompt (see 4.5)
   - Embed first-aid playbooks
   - Safety rules enforcement
   - Scenario state machine logic (NONE → DETECTED → ACTIVE → END)
   - Confidence gating

4. **Model Handoff Logic**
   - VLM observations → passed to Coordinator
   - Coordinator decisions → trigger PersonaPlex conversations
   - PersonaPlex responses → included in next Coordinator context
   - Streaming preservation during handoffs

5. **Tool Chaining**
   - Sequence management (e.g., play_audio → start_metronome → start_timer)
   - Parallel execution where safe
   - Tool call logging

6. **Dedalus Configuration**
   - Model selection strategy (when to use which model)
   - Context window management
   - Streaming configuration
   - Rate limiting, quotas

**Tech Stack:**
- Dedalus SDK (Python)
- Claude API (via Dedalus)
- OpenAI API (via Dedalus for VLM)
- Modal for hosting

**Integration Points:**
- **With Backend Engineer:** VLM worker API, PersonaPlex worker API, WebSocket gateway
- **With Voice Engineer:** PersonaPlex prompt templates, safety rules
- **With Mobile Engineer:** Tool command formats

**Milestones:**
- T+4h: Dedalus SDK installed, basic agent running with dummy tools
- T+7h: VLM integration via analyze_scene tool working
- T+9h: PersonaPlex integration via converse_with_user tool working
- T+11h: All tools defined and tested individually
- T+13h: Coordinator agent with full system prompt, playbooks embedded
- T+15h: End-to-end orchestration flow working (VLM → Coordinator → PersonaPlex → Tools)
- T+16h: Edge case handling, error recovery

---

### ROLE D: Voice/Safety Engineer

**Primary Deliverable:** PersonaPlex setup, safety prompts, observability integration, demo preparation

**Responsibilities:**

1. **PersonaPlex Configuration**
   - Select appropriate voice prompt (calm, clear, supportive)
   - Create base text prompt for first-aid coach persona
   - Test voice quality, tone, pacing
   - Audio format optimization for glasses speaker
   - Latency testing

2. **Safety Prompt Engineering**
   - Refine Coordinator system prompt for safety
   - Test against adversarial inputs:
     - User asks for diagnosis
     - User requests non-playbook actions
     - Ambiguous scenarios
   - Create safety test cases
   - Output validation (detect diagnosis keywords)

3. **First-Aid Playbooks**
   - Research CPR guidelines (AHA/Red Cross)
   - Research bleeding control steps
   - Research choking response (adult)
   - Translate into clear, short instructions
   - Embed in Coordinator prompt
   - Validate with medical advisor if available

4. **Observability Integration**
   - Set up Langfuse project
   - Instrument Dedalus calls for tracing
   - Configure trace collection:
     - VLM calls
     - PersonaPlex conversations
     - Coordinator reasoning
     - Tool executions
   - Create Langfuse dashboard for demo

5. **Replay Dashboard**
   - Build UI to visualize event timeline
   - Show:
     - Frame thumbnails (blurred)
     - VLM observations
     - PersonaPlex transcripts
     - Coordinator decisions
     - Tool calls
     - Timestamps
   - "Why did it say that?" explainability

6. **Demo Preparation**
   - Write demo script (3 scenarios)
   - Prepare fallback plan if Ray-Ban fails
   - Record backup video clip
   - Test end-to-end flow
   - Prepare talking points for judges
   - Create slide deck (optional)

7. **ElevenLabs Fallback (if PersonaPlex issues)**
   - Set up ElevenLabs TTS API
   - Voice selection
   - Latency testing
   - Integration as backup for play_audio tool

**Tech Stack:**
- PersonaPlex (NVIDIA)
- Langfuse (observability)
- ElevenLabs (TTS fallback)
- Testing frameworks

**Integration Points:**
- **With Dedalus Engineer:** System prompt collaboration, tool testing
- **With Backend Engineer:** PersonaPlex worker configuration
- **With Mobile Engineer:** Audio format requirements, replay UI data

**Milestones:**
- T+3h: PersonaPlex voice prompt selected, basic prompts tested
- T+6h: First-aid playbooks researched and written
- T+8h: Safety prompt engineering complete, test cases passing
- T+10h: Langfuse integration working, traces visible
- T+12h: Replay dashboard showing event timeline
- T+14h: Demo script written, tested once end-to-end
- T+15h: ElevenLabs fallback ready (if needed)
- T+16h: Demo polished, backup plan ready

---

## 6) Integration Plan

### 6.1 Integration Points Matrix

| Component | Integrates With | Interface | Data Format |
|-----------|----------------|-----------|-------------|
| Mobile App | Backend Gateway | WebSocket | JSON messages |
| Mobile App | Local Tools | Function calls | Native |
| Backend Gateway | Dedalus Engine | Function calls | Python |
| Dedalus Engine | VLM Worker | HTTP/gRPC | base64 JPEG → JSON |
| Dedalus Engine | PersonaPlex Worker | HTTP/gRPC | Audio bytes → Audio + JSON |
| Dedalus Engine | Coordinator Agent | Dedalus SDK | Tool calls |
| Coordinator Agent | Mobile App (via Gateway) | WebSocket | Tool commands (JSON) |
| All Services | Langfuse | SDK/HTTP | Trace data |

### 6.2 Message Schemas

**Client → Backend (WebSocket)**
```json
{
  "type": "frame",
  "session_id": "abc123",
  "timestamp": 1738940000,
  "frame_b64": "base64_jpeg_string"
}
```

```json
{
  "type": "audio",
  "session_id": "abc123",
  "timestamp": 1738940000,
  "audio_b64": "base64_audio_bytes"
}
```

**Backend → Client (WebSocket)**
```json
{
  "type": "tool_command",
  "tool": "start_metronome",
  "params": {"bpm": 110}
}
```

```json
{
  "type": "audio_response",
  "audio_b64": "base64_audio_from_personaplex",
  "transcript": "Are they breathing normally?"
}
```

**VLM Worker Response**
```json
{
  "observations": "person lying on ground, not moving, blood visible near head",
  "visible_cues": ["unresponsive", "blood", "pale_skin"],
  "confidence": 0.85,
  "risk_flags": ["severe_bleeding", "unconscious"]
}
```

**PersonaPlex Worker Request**
```json
{
  "audio_b64": "base64_user_audio",
  "text_prompt": "You are a calm first-aid coach. Scene: person unresponsive. Ask if they are breathing.",
  "voice_prompt": "calm_coach"
}
```

**PersonaPlex Worker Response**
```json
{
  "audio_b64": "base64_response_audio",
  "transcript": "Are they breathing normally? Check for chest rise.",
  "duration_ms": 3200
}
```

### 6.3 Integration Timeline

**Day 1 Morning (Hours 0-6)**
- All: Initial setup, repo structure, API keys
- Mobile + Backend: WebSocket protocol agreement
- Backend + Dedalus: Service API contracts
- Dedalus + Voice: System prompt collaboration

**Day 1 Afternoon (Hours 6-12)**
- Mobile: Frame capture + blur working, send to backend
- Backend: VLM worker returning observations
- Backend: PersonaPlex worker deployed, basic I/O
- Dedalus: Tools defined, calling VLM/PersonaPlex workers
- Voice: Langfuse integration started

**Day 1 Evening (Hours 12-16)**
- All: End-to-end integration
- Integration test: Frame → VLM → Coordinator → Tool → Client
- Integration test: Audio → PersonaPlex → Coordinator → Audio response
- Demo script testing
- Bug fixes, edge cases
- Backup plan preparation

---

## 7) 16-Hour Execution Timeline

**Hour 0-2: Setup & Alignment**
- Repo setup, API keys, environment
- Review architecture, message schemas
- Initial code scaffolding

**Hour 2-6: Core Services**
- Mobile: Frame capture + MediaPipe blur
- Backend: WebSocket gateway + VLM worker
- Dedalus: SDK setup + basic agent
- Voice: PersonaPlex voice selection

**Hour 6-10: Integration Phase 1**
- Mobile: WebSocket streaming working
- Backend: PersonaPlex worker deployed
- Dedalus: All tools defined, VLM + PersonaPlex integrated
- Voice: Playbooks written, safety prompts tested

**Hour 10-13: Integration Phase 2**
- Full orchestration flow working
- Local tool executors (metronome, timer) functional
- Audio routing to glasses
- Langfuse traces visible

**Hour 13-15: Polish & Demo Prep**
- Replay dashboard
- Demo script testing
- Edge case handling
- Fallback plans (Option B camera, ElevenLabs TTS)

**Hour 15-16: Final Touches**
- Backup video recording
- Slide deck (optional)
- Run-through with whole team
- Deploy to production

---

## 8) Demo Script

**Setup:**
- User wearing Ray-Ban glasses
- Phone in pocket, app running
- Teammate on ground acting as victim

**Scenario 1: CPR (2 minutes)**
1. User: "Hey, someone collapsed here!"
2. System: [analyzes scene] "I see someone on the ground. Are they responding to you?"
3. User: "No, they're not responding."
4. System: "Check if they're breathing normally. Look for chest rise."
5. User: "No, they're not breathing."
6. System: "Call emergency services now. I'll guide you through CPR."
   [Metronome starts at 110 BPM]
   [Timer shows: "Switch rescuer in 2:00"]
7. System: "Place your hands in the center of their chest. Press hard and fast with the beat."
   [User pretends to do compressions]
8. System: [after 30s] "You're doing great. Keep going."

**Scenario 2: Severe Bleeding (1 minute)**
1. [Victim holds red cloth to head]
2. User: "There's blood everywhere!"
3. System: [analyzes scene] "I see bleeding. Is it still flowing heavily?"
4. User: "Yes, it's bad."
5. System: "Call emergency services now. Apply firm direct pressure to the wound."
   [UI shows: checklist with pressure instructions]
   [Timer starts: "Check pressure in 2:00"]

**Scenario 3: Choking (1 minute)**
1. [Victim makes choking gesture, clutching throat]
2. User: "They're choking!"
3. System: [analyzes scene] "I see they're holding their throat. Can they speak or cough?"
4. User: "No, they can't cough."
5. System: "Call emergency services now. Stand behind them and give upward abdominal thrusts."
   [UI shows: Heimlich maneuver steps]

**Finally: Replay Demo (1 minute)**
- Open replay timeline
- Show judges:
  - VLM observations (blurred frames)
  - PersonaPlex conversation transcripts
  - Coordinator decisions
  - Tool calls with timestamps
  - "Why did it say that?" — show Langfuse trace

**Total demo time: ~5 minutes**

---

## 9) Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Ray-Ban stream integration fails | High | Option B: Phone camera fallback (same downstream flow) |
| PersonaPlex latency > 2s | Medium | ElevenLabs TTS fallback for play_audio tool |
| VLM returns inconsistent JSON | High | Retry logic + fallback parsing + strict prompt |
| Dedalus SDK learning curve | Medium | Start with simple agent, add complexity incrementally |
| MediaPipe too slow | Low | Blur only when storing frames; skip for live inference if needed |
| GPU instance unavailable | High | Reserve Modal GPU ahead of time; fallback to CPU PersonaPlex (degraded) |
| Tool execution failures | Medium | Error handling, retry logic, graceful degradation |
| Coordinator hallucinates actions | Critical | Strict tool allowlist, output validation, safety checks |

---

## 10) Success Criteria

**Functional:**
- ✅ End-to-end loop works live with <3s response time
- ✅ All 3 scenarios trigger correctly in demo conditions
- ✅ Metronome + timers run reliably and feel "agentic"
- ✅ PersonaPlex voice is clear, calm, supportive
- ✅ Safety framing is visible ("Call emergency services")

**Technical:**
- ✅ Dedalus orchestrates VLM + PersonaPlex + Coordinator seamlessly
- ✅ Model handoffs preserve context
- ✅ All tool calls logged in Langfuse
- ✅ Replay dashboard shows full decision trace

**Demo:**
- ✅ Judges can see "why it made each decision"
- ✅ Live demo works (or backup video is ready)
- ✅ Clear differentiation from "just an LLM chatbot"
- ✅ Team can explain Dedalus value prop

---

## 11) Appendix: Technology Stack Summary

**Client:**
- React Native OR native iOS/Android
- MediaPipe (face detection & blur)
- WebSocket client
- Audio APIs

**Backend:**
- Modal (Python hosting)
- FastAPI (WebSocket gateway)
- Postgres/Supabase (session store)
- OpenAI GPT-4o Vision (VLM)
- NVIDIA PersonaPlex (voice)

**Orchestration:**
- Dedalus SDK (agent orchestration)
- Claude Sonnet 4 (coordinator agent)
- Langfuse (observability)

**Fallbacks:**
- Phone camera (if Ray-Ban fails)
- ElevenLabs TTS (if PersonaPlex has issues)

---

**End of PRD v2**
