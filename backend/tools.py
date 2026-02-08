# Tool definitions for OpenAI Realtime session.
# These are sent via session.update and the model can call them during conversation.
# When called, the backend routes them as JSON commands to the iOS app.

REALTIME_TOOLS = [
    {
        "type": "function",
        "name": "set_scenario",
        "description": "Call this whenever you determine or update what situation you're dealing with. Call it as soon as you have a reasonable understanding from the conversation — don't wait for full certainty. Also call it with 'resolved' when the situation is handled, or 'none' if it turns out to not be an emergency.",
        "parameters": {
            "type": "object",
            "properties": {
                "scenario": {
                    "type": "string",
                    "enum": [
                        "cpr",
                        "bleeding",
                        "choking",
                        "burn",
                        "fracture",
                        "allergic_reaction",
                        "wound_care",
                        "other_emergency",
                        "minor_injury",
                        "resolved",
                        "none",
                    ],
                    "description": "The current situation type",
                },
                "severity": {
                    "type": "string",
                    "enum": ["critical", "moderate", "minor"],
                    "description": "How severe the situation is",
                },
                "summary": {
                    "type": "string",
                    "description": "Brief one-line summary of what's happening (e.g. 'adult not breathing, starting CPR')",
                },
                "body_region": {
                    "type": "string",
                    "enum": [
                        "head",
                        "neck",
                        "chest",
                        "abdomen",
                        "pelvis",
                        "left_arm",
                        "right_arm",
                        "left_leg",
                        "right_leg",
                        "full_body",
                    ],
                    "description": "Primary body region involved. E.g. 'chest' for CPR, 'left_arm' for a cut on left arm, 'abdomen' for choking/Heimlich, 'neck' for choking airway, 'full_body' for seizure/recovery position.",
                },
            },
            "required": ["scenario", "severity"],
        },
    },
    {
        "type": "function",
        "name": "start_metronome",
        "description": "Start a rhythmic metronome beep for CPR timing. Use 110 BPM for CPR compressions.",
        "parameters": {
            "type": "object",
            "properties": {
                "bpm": {
                    "type": "integer",
                    "description": "Beats per minute (100-120 for CPR)",
                }
            },
            "required": ["bpm"],
        },
    },
    {
        "type": "function",
        "name": "stop_metronome",
        "description": "Stop the metronome.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "type": "function",
        "name": "start_timer",
        "description": "Start a named countdown timer. Use for CPR switch reminders (120s) or pressure checks (120s).",
        "parameters": {
            "type": "object",
            "properties": {
                "label": {
                    "type": "string",
                    "description": "Timer label shown to user (e.g. 'switch_rescuer', 'pressure_check')",
                },
                "seconds": {
                    "type": "integer",
                    "description": "Countdown duration in seconds",
                },
            },
            "required": ["label", "seconds"],
        },
    },
    {
        "type": "function",
        "name": "stop_timer",
        "description": "Stop a specific named timer.",
        "parameters": {
            "type": "object",
            "properties": {
                "label": {
                    "type": "string",
                    "description": "Timer label to stop",
                }
            },
            "required": ["label"],
        },
    },
    {
        "type": "function",
        "name": "show_ui",
        "description": "Display a UI card on the user's phone screen. Use for checklists of steps, banners for critical alerts, or informational cards.",
        "parameters": {
            "type": "object",
            "properties": {
                "card_type": {
                    "type": "string",
                    "enum": ["checklist", "banner", "alert"],
                    "description": "Type of UI card",
                },
                "title": {
                    "type": "string",
                    "description": "Card title",
                },
                "items": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of items (for checklist) or single message (for banner/alert)",
                },
            },
            "required": ["card_type", "title", "items"],
        },
    },
]
