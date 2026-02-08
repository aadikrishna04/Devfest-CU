"""
Core orchestrator: bridges iOS client <-> OpenAI Realtime <-> scene analysis.

Four concurrent loops:
1. ios_to_realtime    — audio/frames from iOS → Realtime + frame buffer
2. realtime_to_ios    — Realtime events → audio/transcripts/tools to iOS
3. scene_loop         — periodic VLM analysis → inject into Realtime (secondary)
4. follow_up_loop     — proactive check-ins when user goes quiet during active scenario
"""

import asyncio
import json
import os
import time
import traceback
import uuid

import websockets

from dedalus_agent import analyze_scene
from prompts import REALTIME_SYSTEM_PROMPT
from tools import REALTIME_TOOLS
from session_logger import SessionLogger

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
REALTIME_URL = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17"
SCENE_ANALYSIS_INTERVAL = 8.0


class Orchestrator:
    def __init__(self, ios_ws):
        self.ios_ws = ios_ws
        self.rt_ws = None
        self.latest_frame_b64: str | None = None
        self.recent_user_transcript = ""
        self.scenario_state = "NONE"
        self.scenario_severity = "minor"
        self._shutdown = False
        self._response_in_progress = False
        self._last_scene_observation = ""

        # Timing state for proactive follow-ups
        self._last_user_speech_time = time.time()
        self._last_agent_speech_time = time.time()
        self._follow_up_count = 0  # How many follow-ups we've sent without user response
        
        # Session logging
        session_id = str(uuid.uuid4())
        self.session_logger = SessionLogger(session_id)
        self._current_assistant_text = ""  # Track current assistant response

    async def run(self):
        self.rt_ws = await websockets.connect(
            REALTIME_URL,
            additional_headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "OpenAI-Beta": "realtime=v1",
            },
        )
        print("[Orchestrator] Connected to OpenAI Realtime")
        await self._configure_session()

        await asyncio.gather(
            self._ios_to_realtime_loop(),
            self._realtime_to_ios_loop(),
            self._scene_analysis_loop(),
            self._follow_up_loop(),
            return_exceptions=True,
        )

    async def shutdown(self):
        self._shutdown = True
        if self.rt_ws:
            await self.rt_ws.close()
        
        # Save session logs
        try:
            self.session_logger.save_session_log()
            self.session_logger.generate_ems_report()
        except Exception as e:
            print(f"[Orchestrator] Error saving session logs: {e}")

    async def _configure_session(self):
        await self.rt_ws.send(
            json.dumps(
                {
                    "type": "session.update",
                    "session": {
                        "modalities": ["text", "audio"],
                        "instructions": REALTIME_SYSTEM_PROMPT,
                        "voice": "alloy",
                        "input_audio_format": "pcm16",
                        "output_audio_format": "pcm16",
                        "input_audio_transcription": {"model": "whisper-1"},
                        "turn_detection": {
                            "type": "server_vad",
                            "threshold": 0.5,
                            "prefix_padding_ms": 300,
                            "silence_duration_ms": 700,
                        },
                        "tools": REALTIME_TOOLS,
                        "tool_choice": "auto",
                    },
                }
            )
        )
        print("[Orchestrator] Session configured")

    # ── Loop 1: iOS → Realtime ─────────────────────────────────────────

    async def _ios_to_realtime_loop(self):
        try:
            while not self._shutdown:
                raw = await self.ios_ws.receive_text()
                msg = json.loads(raw)
                msg_type = msg.get("type")

                if msg_type == "audio":
                    await self.rt_ws.send(
                        json.dumps(
                            {
                                "type": "input_audio_buffer.append",
                                "audio": msg["data"],
                            }
                        )
                    )
                elif msg_type == "frame":
                    self.latest_frame_b64 = msg["data"]

        except Exception as e:
            if not self._shutdown:
                print(f"[iOS→RT] Error: {e}")

    # ── Loop 2: Realtime → iOS ─────────────────────────────────────────

    async def _realtime_to_ios_loop(self):
        try:
            async for raw in self.rt_ws:
                if self._shutdown:
                    break

                event = json.loads(raw)
                event_type = event.get("type", "")

                if event_type == "response.audio.delta":
                    await self._send_ios(
                        {"type": "audio", "data": event.get("delta", "")}
                    )

                elif event_type == "response.created":
                    self._response_in_progress = True

                elif event_type == "response.done":
                    self._response_in_progress = False
                    self._last_agent_speech_time = time.time()

                elif event_type == "response.audio_transcript.delta":
                    delta = event.get("delta", "")
                    self._current_assistant_text += delta
                    self.session_logger.log_assistant_transcript(delta, is_delta=True)
                    await self._send_ios(
                        {"type": "transcript", "role": "assistant", "delta": delta}
                    )

                elif event_type == "response.audio_transcript.done":
                    if self._current_assistant_text:
                        self.session_logger.log_assistant_transcript(self._current_assistant_text, is_delta=False)
                        self._current_assistant_text = ""
                    await self._send_ios(
                        {"type": "transcript_done", "role": "assistant"}
                    )

                elif (
                    event_type
                    == "conversation.item.input_audio_transcription.completed"
                ):
                    text = event.get("transcript", "")
                    self.recent_user_transcript = text
                    self._last_user_speech_time = time.time()
                    self._follow_up_count = 0  # Reset — user is engaged
                    self.session_logger.log_user_transcript(text)
                    await self._send_ios(
                        {"type": "transcript", "role": "user", "text": text}
                    )

                elif event_type == "input_audio_buffer.speech_started":
                    self._response_in_progress = False
                    self._last_user_speech_time = time.time()
                    self._follow_up_count = 0
                    self._current_assistant_text = ""  # Reset assistant text on interrupt
                    await self._send_ios({"type": "interrupt"})

                elif event_type == "response.output_item.done":
                    item = event.get("item", {})
                    if item.get("type") == "function_call":
                        await self._handle_tool_call(item)

                elif event_type == "error":
                    err = event.get("error", {})
                    if err.get("code") != "conversation_already_has_active_response":
                        print(f"[Realtime Error] {err}")

                elif event_type in ("session.created", "session.updated"):
                    print(f"[Realtime] {event_type}")

        except Exception as e:
            if not self._shutdown:
                print(f"[RT→iOS] Error: {e}")
                traceback.print_exc()

    # ── Loop 3: Scene Analysis ─────────────────────────────────────────

    async def _scene_analysis_loop(self):
        await asyncio.sleep(3.0)
        try:
            while not self._shutdown:
                await asyncio.sleep(SCENE_ANALYSIS_INTERVAL)

                if not self.latest_frame_b64:
                    continue
                if self._response_in_progress:
                    continue

                try:
                    observation = await analyze_scene(
                        frame_b64=self.latest_frame_b64,
                        scenario_state=self.scenario_state,
                        recent_transcript=self.recent_user_transcript,
                    )
                    if not observation:
                        continue
                    if self._is_similar(observation, self._last_scene_observation):
                        continue

                    self._last_scene_observation = observation
                    self.session_logger.log_scene_observation(observation)

                    await self.rt_ws.send(
                        json.dumps(
                            {
                                "type": "conversation.item.create",
                                "item": {
                                    "type": "message",
                                    "role": "user",
                                    "content": [
                                        {
                                            "type": "input_text",
                                            "text": f"[SCENE UPDATE] {observation}",
                                        }
                                    ],
                                },
                            }
                        )
                    )
                    # Don't auto-trigger response — voice drives the conversation

                    await self._send_ios(
                        {"type": "scene_update", "observation": observation}
                    )
                    print(f"[Scene] {observation[:80]}...")

                except Exception as e:
                    print(f"[Scene] Error: {e}")

        except asyncio.CancelledError:
            pass

    # ── Loop 4: Proactive Follow-ups ───────────────────────────────────

    async def _follow_up_loop(self):
        """
        When the user goes quiet during an active scenario, nudge the model
        to check in. The model decides what to say based on context.

        Timing:
        - First follow-up after 30s of silence during active scenario
        - Subsequent follow-ups every 45s
        - Max 3 follow-ups without user response, then stop nagging
        - No follow-ups if scenario is NONE (no emergency detected yet)
        """
        await asyncio.sleep(5.0)
        try:
            while not self._shutdown:
                await asyncio.sleep(5.0)  # Check every 5s

                if self._response_in_progress:
                    continue
                # Only follow up during active, non-trivial scenarios
                inactive = {"NONE", "RESOLVED", "MINOR_INJURY"}
                if self.scenario_state in inactive:
                    continue
                if self.scenario_severity == "minor":
                    continue
                if self._follow_up_count >= 3:
                    continue

                now = time.time()
                silence_duration = now - self._last_user_speech_time
                since_agent_spoke = now - self._last_agent_speech_time

                # Determine follow-up threshold
                threshold = 30.0 if self._follow_up_count == 0 else 45.0

                # Only follow up if enough silence AND agent isn't freshly done talking
                if silence_duration < threshold:
                    continue
                if since_agent_spoke < 15.0:
                    continue

                # Build context-aware follow-up prompt
                elapsed_str = f"{int(silence_duration)}s"
                prompt = self._build_follow_up_prompt(elapsed_str)

                print(f"[Follow-up] {elapsed_str} silence, count={self._follow_up_count}: {prompt[:60]}...")

                await self.rt_ws.send(
                    json.dumps(
                        {
                            "type": "conversation.item.create",
                            "item": {
                                "type": "message",
                                "role": "user",
                                "content": [
                                    {
                                        "type": "input_text",
                                        "text": prompt,
                                    }
                                ],
                            },
                        }
                    )
                )
                await self.rt_ws.send(json.dumps({"type": "response.create"}))

                self._follow_up_count += 1
                self._last_agent_speech_time = now  # Prevent rapid re-triggers

        except asyncio.CancelledError:
            pass

    def _build_follow_up_prompt(self, elapsed: str) -> str:
        """Build a context-aware follow-up injection based on scenario state."""
        base = f"[FOLLOW UP] The user has been quiet for {elapsed}."

        if self.scenario_state == "CPR":
            prompts = [
                f"{base} They're doing CPR. Give a brief word of encouragement or ask if they need to switch.",
                f"{base} Check if they're still doing compressions and if someone else can take over.",
                f"{base} Ask if help has arrived or if they need anything.",
            ]
        elif self.scenario_state == "BLEEDING":
            prompts = [
                f"{base} They're applying pressure to a wound. Ask if the bleeding is slowing down.",
                f"{base} Check if they're still applying pressure and if help is on the way.",
                f"{base} Ask if the situation has changed.",
            ]
        elif self.scenario_state == "CHOKING":
            prompts = [
                f"{base} They're helping someone who was choking. Ask if the obstruction cleared.",
                f"{base} Check if the person can breathe now.",
                f"{base} Ask if the situation has changed.",
            ]
        else:
            prompts = [
                f"{base} Check in briefly — ask if they need help with anything.",
            ]

        idx = min(self._follow_up_count, len(prompts) - 1)
        return prompts[idx]

    # ── Tool Call Handling ──────────────────────────────────────────────

    async def _handle_tool_call(self, item: dict):
        call_id = item.get("call_id", "")
        name = item.get("name", "")
        args_str = item.get("arguments", "{}")

        try:
            args = json.loads(args_str)
        except json.JSONDecodeError:
            args = {}

        print(f"[Tool] {name}({args})")

        # set_scenario is handled server-side — it updates our state
        if name == "set_scenario":
            scenario = args.get("scenario", "none")
            severity = args.get("severity", "minor")
            summary = args.get("summary", "")
            body_region = args.get("body_region", "")
            self.scenario_state = scenario.upper()
            self.scenario_severity = severity
            self.session_logger.log_scenario_update(scenario, severity, summary, body_region)
            print(f"[Scenario] {scenario} ({severity}): {summary} [region: {body_region}]")
            # Notify iOS for potential UI display + wireframe animation
            await self._send_ios({
                "type": "scenario_update",
                "scenario": scenario,
                "severity": severity,
                "summary": summary,
                "body_region": body_region,
            })
        else:
            # All other tools go to iOS for local execution
            self.session_logger.log_tool_call(name, args)
            await self._send_ios({"type": "tool", "name": name, "params": args})

        await self.rt_ws.send(
            json.dumps(
                {
                    "type": "conversation.item.create",
                    "item": {
                        "type": "function_call_output",
                        "call_id": call_id,
                        "output": json.dumps({"status": "ok"}),
                    },
                }
            )
        )

        self._response_in_progress = False
        await self.rt_ws.send(json.dumps({"type": "response.create"}))

    # ── Helpers ─────────────────────────────────────────────────────────

    def _is_similar(self, new: str, old: str) -> bool:
        if not old:
            return False
        return new[:50].lower().strip() == old[:50].lower().strip()

    async def _send_ios(self, data: dict):
        try:
            await self.ios_ws.send_json(data)
        except Exception:
            pass
