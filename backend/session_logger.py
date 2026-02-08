"""
Backend session logger: tracks transcripts, scenarios, and generates reports.
"""

import json
import os
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional


class TranscriptEntry:
    def __init__(self, timestamp: float, role: str, text: str):
        self.timestamp = timestamp
        self.role = role  # "user" or "assistant"
        self.text = text

    def to_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "datetime": datetime.fromtimestamp(self.timestamp).isoformat(),
            "role": self.role,
            "text": self.text,
        }


class SessionLogger:
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.start_time = datetime.now()
        self.transcript_entries: List[TranscriptEntry] = []
        self.scene_observations: List[Dict] = []
        self.scenario_updates: List[Dict] = []
        self.tool_calls: List[Dict] = []
        
        # Current scenario state
        self.current_scenario = "none"
        self.current_severity = "minor"
        self.current_summary = ""
        self.current_body_region = ""

    def log_user_transcript(self, text: str):
        """Log a user transcript entry."""
        entry = TranscriptEntry(time.time(), "user", text)
        self.transcript_entries.append(entry)
        print(f"[SessionLogger] User: {text[:50]}...")

    def log_assistant_transcript(self, text: str, is_delta: bool = False):
        """Log an assistant transcript entry."""
        if is_delta and self.transcript_entries and self.transcript_entries[-1].role == "assistant":
            # Append to last entry if it's a delta
            self.transcript_entries[-1].text += text
        else:
            entry = TranscriptEntry(time.time(), "assistant", text)
            self.transcript_entries.append(entry)
        if not is_delta:
            print(f"[SessionLogger] Assistant: {text[:50]}...")

    def log_scene_observation(self, observation: str):
        """Log a scene observation."""
        entry = {
            "timestamp": time.time(),
            "datetime": datetime.now().isoformat(),
            "observation": observation,
        }
        self.scene_observations.append(entry)

    def log_scenario_update(self, scenario: str, severity: str, summary: str, body_region: str):
        """Log a scenario update."""
        self.current_scenario = scenario
        self.current_severity = severity
        self.current_summary = summary
        self.current_body_region = body_region
        
        entry = {
            "timestamp": time.time(),
            "datetime": datetime.now().isoformat(),
            "scenario": scenario,
            "severity": severity,
            "summary": summary,
            "body_region": body_region,
        }
        self.scenario_updates.append(entry)

    def log_tool_call(self, tool_name: str, params: dict):
        """Log a tool call."""
        entry = {
            "timestamp": time.time(),
            "datetime": datetime.now().isoformat(),
            "tool": tool_name,
            "params": params,
        }
        self.tool_calls.append(entry)

    def save_session_log(self, output_dir: Optional[str] = None) -> str:
        """Save session log as JSON file."""
        if output_dir is None:
            output_dir = os.path.join(os.getcwd(), "session_logs")
        
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        log_data = {
            "session_id": self.session_id,
            "start_time": self.start_time.isoformat(),
            "end_time": datetime.now().isoformat(),
            "duration_seconds": (datetime.now() - self.start_time).total_seconds(),
            "transcript_entries": [e.to_dict() for e in self.transcript_entries],
            "scene_observations": self.scene_observations,
            "scenario_updates": self.scenario_updates,
            "tool_calls": self.tool_calls,
            "current_scenario": {
                "scenario": self.current_scenario,
                "severity": self.current_severity,
                "summary": self.current_summary,
                "body_region": self.current_body_region,
            },
        }
        
        filename = f"{self.session_id}_session_log.json"
        filepath = os.path.join(output_dir, filename)
        
        with open(filepath, "w") as f:
            json.dump(log_data, f, indent=2)
        
        print(f"[SessionLogger] Saved session log to {filepath}")
        return filepath

    def generate_ems_report(self, output_dir: Optional[str] = None) -> str:
        """Generate EMS-ready text report."""
        if output_dir is None:
            output_dir = os.path.join(os.getcwd(), "session_logs")
        
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        report_lines = [
            "=" * 50,
            "EMS READY REPORT - FIRST AID SESSION",
            "=" * 50,
            "",
            "SESSION INFORMATION",
            "-" * 50,
            f"Session ID: {self.session_id}",
            f"Start Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}",
            f"End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Duration: {(datetime.now() - self.start_time).total_seconds():.1f} seconds",
            "",
        ]
        
        if self.current_scenario != "none":
            report_lines.extend([
                "SCENARIO DETAILS",
                "-" * 50,
                f"Type: {self.current_scenario.upper()}",
                f"Severity: {self.current_severity.upper()}",
                f"Body Region: {self.current_body_region}",
                f"Summary: {self.current_summary}",
                "",
            ])
        
        if self.scene_observations:
            report_lines.extend([
                "SCENE OBSERVATIONS",
                "-" * 50,
            ])
            for i, obs in enumerate(self.scene_observations, 1):
                dt = datetime.fromisoformat(obs["datetime"])
                report_lines.append(f"{i}. [{dt.strftime('%H:%M:%S')}] {obs['observation']}")
            report_lines.append("")
        
        report_lines.extend([
            "CONVERSATION TRANSCRIPT",
            "-" * 50,
        ])
        
        for entry in self.transcript_entries:
            dt = datetime.fromtimestamp(entry.timestamp)
            role = entry.role.upper()
            report_lines.append(f"[{dt.strftime('%H:%M:%S')}] {role}: {entry.text}")
            report_lines.append("")
        
        report_lines.extend([
            "",
            "KEY INFORMATION SUMMARY",
            "-" * 50,
        ])
        
        user_statements = [e.text for e in self.transcript_entries if e.role == "user"]
        assistant_instructions = [e.text for e in self.transcript_entries if e.role == "assistant"]
        
        report_lines.append(f"User Statements ({len(user_statements)} total):")
        for statement in user_statements:
            report_lines.append(f"  • {statement}")
        
        report_lines.append("")
        report_lines.append(f"Assistant Instructions ({len(assistant_instructions)} total):")
        for instruction in assistant_instructions:
            report_lines.append(f"  • {instruction}")
        
        if self.tool_calls:
            report_lines.extend([
                "",
                "TOOL CALLS",
                "-" * 50,
            ])
            for call in self.tool_calls:
                dt = datetime.fromisoformat(call["datetime"])
                report_lines.append(f"[{dt.strftime('%H:%M:%S')}] {call['tool']}: {json.dumps(call['params'])}")
        
        report_lines.extend([
            "",
            "=" * 50,
            "END OF REPORT",
            "=" * 50,
        ])
        
        report_text = "\n".join(report_lines)
        
        filename = f"{self.session_id}_EMS_Report.txt"
        filepath = os.path.join(output_dir, filename)
        
        with open(filepath, "w") as f:
            f.write(report_text)
        
        print(f"[SessionLogger] Generated EMS report: {filepath}")
        return filepath
