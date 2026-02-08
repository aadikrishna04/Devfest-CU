"""
Scene analysis via GPT-4o Vision.

Primary: Dedalus SDK (DAuth credential isolation — API keys encrypted
client-side, decrypted only inside sealed hardware enclaves).
Fallback: Direct OpenAI if Dedalus unavailable.
"""

import os

from dedalus_labs import AsyncDedalus
from openai import AsyncOpenAI

from prompts import DEDALUS_SCENE_PROMPT

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
DEDALUS_API_KEY = os.environ.get("DEDALUS_API_KEY", "")


def _build_messages(frame_b64: str, context: str) -> list[dict]:
    return [
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
    ]


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

    # Primary: Dedalus (DAuth credential isolation)
    if DEDALUS_API_KEY:
        result = await _analyze_with_dedalus(frame_b64, context)
        if result:
            return result

    # Fallback: direct OpenAI
    return await _analyze_with_openai(frame_b64, context)


async def _analyze_with_dedalus(frame_b64: str, context: str) -> str | None:
    try:
        client = AsyncDedalus(api_key=DEDALUS_API_KEY)
        response = await client.chat.completions.create(
            model="openai/gpt-4o",
            messages=_build_messages(frame_b64, context),
            max_tokens=100,
        )
        print("[VLM] Dedalus call succeeded")
        return response.choices[0].message.content
    except Exception as e:
        print(f"[VLM] Dedalus error: {e}")
        return None


async def _analyze_with_openai(frame_b64: str, context: str) -> str | None:
    try:
        client = AsyncOpenAI(api_key=OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=_build_messages(frame_b64, context),
            max_tokens=100,
        )
        print("[VLM] OpenAI fallback call succeeded")
        return response.choices[0].message.content
    except Exception as e:
        print(f"[VLM] OpenAI error: {e}")
        return None
