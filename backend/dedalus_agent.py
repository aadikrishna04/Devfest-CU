"""
Scene analysis via GPT-4o Vision.

Uses Dedalus if available, falls back to direct OpenAI.
"""

import os

from openai import AsyncOpenAI

from prompts import DEDALUS_SCENE_PROMPT

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
DEDALUS_API_KEY = os.environ.get("DEDALUS_API_KEY", "")


async def analyze_scene(
    frame_b64: str,
    scenario_state: str,
    recent_transcript: str,
) -> str | None:
    """
    Analyze a camera frame. Returns a factual scene description (1-2 sentences).
    """
    context = f"Current scenario: {scenario_state}."
    if recent_transcript:
        context += f" User just said: {recent_transcript}"

    # Direct OpenAI call (Dedalus integration can be swapped in later)
    return await _analyze_with_openai(frame_b64, context)


async def _analyze_with_openai(frame_b64: str, context: str) -> str | None:
    try:
        client = AsyncOpenAI(api_key=OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": DEDALUS_SCENE_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": context},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{frame_b64}",
                                "detail": "low",
                            },
                        },
                    ],
                },
            ],
            max_tokens=100,
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"[VLM] Error: {e}")
        return None
