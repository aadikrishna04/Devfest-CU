# MedKit First-Aid Coach - Complete App Summary

## Overview
**MedKit** is a hands-free first-aid coaching application that transforms Meta Ray-Ban smart glasses into a real-time medical assistance system. The app provides voice-guided, AI-powered first-aid instructions to bystanders during medical emergencies, helping them take immediate action while waiting for emergency services.

## Core Concept
**"Point-of-care first-aid guidance in your ear, triggered by what you're seeing, with timers and rhythm assistance."**

The app uses the wearer's point-of-view video and voice to understand emergency situations and provides step-by-step guidance through the glasses' speakers, with visual aids displayed on a connected iPhone.

## Key Features

### 1. Real-Time AI Assistance
- **Voice-activated**: Wake word "Medkit" activates the system
- **Natural conversation**: AI responds to user questions and provides guidance
- **Scene analysis**: Continuously analyzes video frames to understand the situation
- **Proactive check-ins**: Automatically checks in if user goes quiet during emergencies

### 2. Emergency Scenario Support
Supports three primary emergency scenarios:
- **CPR Assistance**: Guides through cardiopulmonary resuscitation with metronome timing
- **Severe Bleeding**: Provides wound care instructions and pressure application guidance
- **Adult Choking**: Guides through Heimlich maneuver and airway clearing

### 3. Interactive Tools
- **Metronome**: Audio beats at 110 BPM for CPR compressions
- **Timers**: Countdown timers for pressure checks, rescuer switches, etc.
- **Visual Checklists**: Step-by-step instructions displayed on phone
- **3D Wireframe Guides**: Animated body guides showing where to focus (chest, arm, etc.)

### 4. Session Logging & Export (NEW)
- **Video Recording**: Automatically records session video, exports as MP4
- **Transcript Logging**: Captures all conversations with timestamps
- **PDF Export**: Generates formatted transcript PDFs with session metadata
- **EMS Reports**: Creates comprehensive text reports for emergency medical services

### 5. Privacy & Safety
- **Face Blurring**: MediaPipe automatically blurs faces in video frames
- **Safety Disclaimers**: Always displays "Decision support only - call emergency services"
- **Confidence Gating**: Only provides instructions when confident about the situation
- **No Diagnosis**: System explicitly avoids medical diagnosis

## Technical Architecture

### Frontend (iOS App)
**Technology Stack:**
- SwiftUI for user interface
- Meta Ray-Ban SDK (MWDATCamera, MWDATCore) for glasses integration
- AVFoundation for audio/video processing
- WebSocket for real-time backend communication

**Key Components:**
- `MetaCameraView`: Main UI with streaming interface
- `StreamViewModel`: Manages streaming session and state
- `AudioManager`: Handles audio capture, wake word detection, playback
- `WebSocketManager`: Manages backend communication
- `ToolExecutor`: Executes metronome, timers, UI cards locally
- `SessionLogger`: Records video, transcripts, generates exports
- `ExportView`: UI for exporting session data

**Features:**
- Real-time video streaming from glasses
- Audio capture with wake word detection
- Local tool execution (metronome, timers)
- 3D wireframe visualization for body regions
- Session recording and export capabilities

### Backend (Python/Modal)
**Technology Stack:**
- Modal for cloud hosting
- FastAPI for WebSocket gateway
- OpenAI Realtime API for voice conversation
- GPT-4o Vision for scene analysis
- Python async/await for concurrent processing

**Key Components:**
- `app.py`: Modal deployment configuration
- `orchestrator.py`: Core orchestration engine managing four concurrent loops:
  1. iOS → Realtime: Audio/frames from client
  2. Realtime → iOS: AI responses, transcripts, tools
  3. Scene Analysis Loop: Periodic VLM analysis
  4. Follow-up Loop: Proactive check-ins during emergencies
- `dedalus_agent.py`: Scene analysis using GPT-4o Vision
- `session_logger.py`: Backend logging and report generation
- `prompts.py`: System prompts for AI behavior
- `tools.py`: Tool definitions (metronome, timers, UI cards)

**Architecture Flow:**
```
iOS App → WebSocket → Modal Backend → OpenAI Realtime API
                ↓
         Scene Analysis (GPT-4o Vision)
                ↓
         Tool Execution → iOS App
```

## How It Works

### 1. Session Start
1. User opens app and connects Meta Ray-Ban glasses
2. Taps "Start Session" button
3. App requests camera and microphone permissions
4. Establishes WebSocket connection to Modal backend
5. Begins streaming video frames (every 3 seconds) and audio

### 2. Wake Word Activation
1. User says "Medkit" (or variations like "med kit", "medic")
2. Speech recognition detects wake word
3. System activates and starts listening
4. Audio streams to backend for processing

### 3. Emergency Detection
1. **User describes situation**: "Someone collapsed!"
2. **AI asks clarifying questions**: "Are they responding? Are they breathing?"
3. **Scene analysis**: VLM analyzes video frames every 8 seconds
4. **Scenario identification**: System determines emergency type (CPR, bleeding, choking)
5. **Confidence check**: Only proceeds if confident or user confirms

### 4. Guidance Delivery
1. **Initial instruction**: "Call emergency services now"
2. **Tool activation**: 
   - Metronome starts for CPR (110 BPM)
   - Timer starts for pressure checks or rescuer switches
   - Checklist appears on phone screen
3. **Step-by-step guidance**: AI provides next steps via voice
4. **Visual aids**: 3D wireframe highlights relevant body region
5. **Proactive check-ins**: System checks in if user is quiet

### 5. Session Logging
- **During session**: Video frames recorded, transcripts logged with timestamps
- **After session**: User can export:
  - Video (MP4)
  - Transcript PDF
  - EMS Report (TXT)

## Data Flow

### Input Streams
1. **Video**: Frames from glasses camera (sampled every 3 seconds)
2. **Audio**: User voice from glasses microphone
3. **Scene Context**: Current scenario state, recent transcripts

### Processing
1. **Voice → Text**: OpenAI Realtime API transcribes user speech
2. **Vision Analysis**: GPT-4o Vision analyzes video frames
3. **Decision Making**: AI coordinator integrates voice + vision to determine actions
4. **Tool Execution**: Commands sent to iOS app for local execution

### Output Streams
1. **Audio Response**: AI voice guidance through glasses speakers
2. **Visual UI**: Checklists, timers, wireframes on phone
3. **Audio Tools**: Metronome beats, timer alerts
4. **Session Logs**: Video, transcripts, reports

## AI Models Used

### 1. OpenAI Realtime API (GPT-4o Realtime)
- **Purpose**: Natural voice conversation
- **Features**: Streaming audio, real-time transcription, low latency
- **Voice**: "alloy" voice model
- **Format**: PCM16, 24kHz audio

### 2. GPT-4o Vision
- **Purpose**: Scene analysis from video frames
- **Frequency**: Every 8 seconds
- **Output**: Factual scene descriptions (1-2 sentences)
- **Detail Level**: Currently "low" (can upgrade to "high")

### 3. System Coordinator (via Realtime API)
- **Purpose**: Decision making, scenario management, tool execution
- **Capabilities**: 
  - Integrates voice + vision inputs
  - Maintains scenario state
  - Executes tools (metronome, timers, UI)
  - Enforces safety rules

## Safety Features

### Built-in Safeguards
1. **Always recommends calling 911** for any emergency
2. **Confidence gating**: Only provides instructions when confident
3. **No diagnosis**: Explicitly avoids medical diagnosis
4. **Playbook-based**: Only provides established first-aid procedures
5. **User confirmation**: Asks clarifying questions before acting
6. **Safety disclaimers**: Always visible in UI

### Privacy Protection
1. **Face blurring**: MediaPipe blurs faces before cloud upload
2. **Local storage**: Session data stored locally on device
3. **User control**: User decides what to export/share
4. **No persistent video**: Only processes frames, doesn't store full video

## Supported Scenarios

### Primary (MVP)
1. **CPR**: Unresponsive person, not breathing normally
2. **Severe Bleeding**: Heavy external bleeding
3. **Adult Choking**: Airway obstruction

### Extended (via tools)
- Burns
- Fractures
- Allergic reactions
- Wound care
- Minor injuries

## User Experience

### Interface Elements
- **Status Bar**: Shows connection status, wake word state, scenario type
- **Video Feed**: Live view from glasses camera
- **Audio Visualizer**: Visual feedback when listening
- **3D Wireframe**: Animated guide showing body regions
- **Transcript Display**: Real-time conversation transcript
- **Tool Overlays**: Metronome, timers, checklists
- **Export Button**: Access to session exports

### Interaction Modes
1. **Wake Word Mode**: System waits for "Medkit" activation
2. **Emergency Mode**: System stays active during critical scenarios
3. **Conversation Mode**: Natural back-and-forth dialogue
4. **Guidance Mode**: Step-by-step instruction delivery

## Recent Enhancements (Session Logging)

### New Capabilities
1. **Automatic Video Recording**: Records entire session as MP4
2. **Transcript Logging**: Captures all conversations with precise timestamps
3. **PDF Export**: Formatted transcripts with session metadata
4. **EMS Report Generation**: Comprehensive reports for medical professionals
5. **Backend Logging**: Server-side logging for redundancy

### Export Features
- **Video (MP4)**: Full session recording, 30 FPS, H.264 encoding
- **Transcript PDF**: Includes session info, scenarios, scene observations, full conversation
- **EMS Report**: Text report with session details, key information, tool calls

## Technical Specifications

### Performance
- **Video Frame Rate**: 24 FPS from glasses, sampled every 3 seconds
- **Audio**: PCM16, 24kHz, mono
- **Latency**: <3 seconds for voice responses
- **Scene Analysis**: Every 8 seconds
- **Wake Word**: ~15 second timeout if inactive

### Storage
- **Video**: ~2MB per minute (640x480, H.264)
- **Transcripts**: Minimal storage (text)
- **Session Logs**: JSON format, ~10-50KB per session

### Requirements
- **iOS**: iOS 15+
- **Hardware**: Meta Ray-Ban smart glasses
- **Network**: Internet connection for backend
- **Permissions**: Camera, microphone, speech recognition

## Use Cases

### Primary Use Case
**Bystander encounters medical emergency** → Activates MedKit → Receives real-time guidance → Takes action while waiting for EMS

### Secondary Use Cases
1. **Training**: Practice first-aid procedures with AI guidance
2. **Review**: Analyze session transcripts to improve responses
3. **Documentation**: Generate reports for medical professionals
4. **Education**: Learn proper first-aid techniques

## Future Enhancements

### Potential Additions
- Cloud storage for automatic backup
- Multi-language support
- Pediatric emergency support
- Integration with emergency services
- Offline mode with on-device models
- Advanced analytics dashboard
- Custom scenario training

## Development Status

### Completed
- ✅ Core streaming infrastructure
- ✅ Wake word detection
- ✅ Scene analysis integration
- ✅ Tool execution (metronome, timers, UI)
- ✅ Session logging and export
- ✅ Backend orchestration
- ✅ Safety features

### In Progress / Planned
- 🔄 VLM model optimization
- 🔄 Enhanced scene analysis accuracy
- 🔄 Additional emergency scenarios
- 🔄 Performance optimizations

## Summary

MedKit is a comprehensive first-aid assistance system that combines:
- **Wearable technology** (Meta Ray-Ban glasses)
- **AI-powered guidance** (OpenAI Realtime + Vision)
- **Real-time scene analysis** (GPT-4o Vision)
- **Interactive tools** (metronome, timers, checklists)
- **Complete session logging** (video, transcripts, reports)

The system helps non-expert bystanders provide effective first-aid during emergencies while maintaining safety, privacy, and comprehensive documentation for medical professionals.
