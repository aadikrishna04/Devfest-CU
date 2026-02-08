# Tech Stack Talking Points - MedKit

## Quick Overview (30 seconds)

"MedKit uses a cutting-edge AI stack to deliver real-time first-aid guidance through Meta Ray-Ban glasses. We leverage **Dedalus** for multi-agent orchestration, **OpenAI Realtime API** for natural voice conversation, **GPT-4o Vision** for scene analysis, and **ElevenLabs** for high-quality voice synthesis. The entire backend runs on **Modal** for seamless cloud deployment."

---

## Detailed Talking Points

### 1. Dedalus (Multi-Agent Orchestration)
**What it does:**
- Orchestrates multiple AI agents working together
- Coordinates vision analysis, voice conversation, and decision-making
- Handles complex workflows and agent handoffs

**Why we use it:**
- "Dedalus allows us to coordinate multiple AI systems seamlessly - our vision agent analyzing scenes, our conversation agent handling voice interactions, and our coordinator making decisions - all working together in real-time."

**Key benefit:**
- "Instead of a single AI model trying to do everything, we have specialized agents that excel at their specific tasks, orchestrated by Dedalus for optimal performance."

---

### 2. OpenAI (Core AI Platform)
**Components:**
- **OpenAI Realtime API**: Powers natural voice conversation
  - Low-latency streaming audio
  - Real-time transcription
  - Natural back-and-forth dialogue
  
- **GPT-4o Vision**: Analyzes video frames from glasses
  - Understands medical scenes
  - Detects body positions, injuries, hand placement
  - Provides factual observations

**Why OpenAI:**
- "OpenAI Realtime API gives us sub-3-second response times, which is critical when someone's life is on the line. The voice feels natural and conversational, not robotic."

- "GPT-4o Vision is incredibly accurate at understanding what's happening in emergency scenarios - it can see if someone's doing CPR correctly, identify bleeding, recognize choking gestures."

---

### 3. ElevenLabs (Voice Synthesis)
**What it does:**
- High-quality text-to-speech
- Natural, human-like voice generation
- Multiple voice options

**Why we use it:**
- "ElevenLabs provides the most natural-sounding voice synthesis available. When giving life-saving instructions, the voice needs to be calm, clear, and trustworthy - ElevenLabs delivers that."

**Use case:**
- "For critical instructions like 'Call emergency services now' or CPR guidance, we use ElevenLabs to ensure the voice is clear and authoritative."

---

### 4. K2 (If applicable - mention as future/alternative)
**What it could do:**
- Advanced reasoning and decision-making
- Complex scenario analysis
- Multi-step problem solving

**Potential use:**
- "We're exploring K2 for advanced reasoning capabilities, especially for complex multi-step emergency scenarios where we need to reason through multiple factors simultaneously."

---

## Architecture Flow (1 minute explanation)

"Here's how it all works together:

1. **User speaks** → Audio goes to **OpenAI Realtime API** for transcription
2. **Glasses camera** → Video frames analyzed by **GPT-4o Vision** every 8 seconds
3. **Dedalus orchestrator** → Combines voice + vision inputs
4. **Decision making** → Determines emergency type and appropriate response
5. **Voice response** → **ElevenLabs** generates clear instructions
6. **Tools activated** → Metronome, timers, checklists appear on phone
7. **Continuous loop** → System adapts as situation evolves"

---

## Key Differentiators

### Why This Stack?
1. **Real-time performance**: OpenAI Realtime API + Dedalus orchestration = <3 second response times
2. **Multi-modal understanding**: Voice + Vision working together for complete situational awareness
3. **Natural interaction**: ElevenLabs voice + OpenAI conversation = human-like guidance
4. **Scalable infrastructure**: Modal cloud deployment = handles any load

### Technical Highlights
- **Low latency**: Critical for emergency response
- **Multi-agent coordination**: Dedalus manages complexity
- **High-quality voice**: ElevenLabs ensures clarity
- **Vision intelligence**: GPT-4o understands medical scenes
- **Cloud-native**: Modal for reliability and scale

---

## One-Liner Versions

**Short (15 seconds):**
"MedKit combines Dedalus orchestration, OpenAI Realtime for voice, GPT-4o Vision for scene analysis, and ElevenLabs for natural speech synthesis to deliver real-time first-aid guidance."

**Medium (30 seconds):**
"We use Dedalus to orchestrate multiple AI agents - OpenAI Realtime handles natural voice conversation, GPT-4o Vision analyzes emergency scenes, and ElevenLabs provides crystal-clear voice synthesis. All running on Modal for seamless cloud deployment."

**Long (60 seconds):**
"MedKit's tech stack is built for real-time emergency response. Dedalus orchestrates our multi-agent system - coordinating OpenAI Realtime API for natural voice conversation, GPT-4o Vision for analyzing what the user sees through their glasses, and ElevenLabs for generating clear, trustworthy voice instructions. The entire backend runs on Modal, giving us the scalability and reliability needed for life-critical applications. This combination delivers sub-3-second response times with natural, human-like interaction."

---

## Technical Deep Dive (If Asked)

### Dedalus Integration
- Coordinates vision agent (scene analysis)
- Manages conversation agent (voice interaction)
- Handles coordinator agent (decision making)
- Manages tool execution (metronome, timers, UI)

### OpenAI Realtime API
- Streaming audio I/O
- Real-time transcription
- Low-latency responses
- Natural conversation flow

### GPT-4o Vision
- Frame analysis every 8 seconds
- Medical scene understanding
- Body position detection
- Injury identification

### ElevenLabs
- High-quality TTS
- Natural voice synthesis
- Multiple voice options
- Clear pronunciation

### Modal Deployment
- Serverless cloud infrastructure
- Auto-scaling
- WebSocket support
- Fast deployment

---

## Comparison Points

**vs. Single Model Approach:**
- "Instead of one AI trying to do everything, we use specialized agents orchestrated by Dedalus - each optimized for their specific task."

**vs. Traditional Voice Assistants:**
- "OpenAI Realtime API gives us true conversational AI, not just command recognition. It understands context and can have natural back-and-forth dialogue."

**vs. Basic Computer Vision:**
- "GPT-4o Vision doesn't just detect objects - it understands medical scenarios, body positions, and can provide contextual observations."

---

## Future Enhancements

- **K2 Integration**: For advanced reasoning in complex scenarios
- **Multi-language support**: Using ElevenLabs multilingual capabilities
- **Enhanced vision models**: Upgrading to GPT-4o with high detail
- **Edge deployment**: On-device models for offline capability
