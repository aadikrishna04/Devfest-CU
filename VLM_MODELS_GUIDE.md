# VLM Models Guide - Improving Vision Performance

## Current Implementation
- **Model**: GPT-4o (via OpenAI)
- **Detail Level**: "low" (for cost/speed)
- **Use Case**: Medical emergency scene analysis

## Recommended Models for Improvement

### 1. **GPT-4o (2024-11-20)** ⭐ Best Overall
**Why**: Latest version with improved vision capabilities
- **Pros**: 
  - Better medical scene understanding
  - Improved accuracy for emergency scenarios
  - Faster inference than previous versions
  - Better at detecting subtle medical cues
- **Cons**: Higher cost than GPT-4o base
- **Implementation**: Change model to `"gpt-4o-2024-11-20"`
- **Best for**: Production use, highest accuracy needed

### 2. **GPT-4o-mini** 💰 Cost-Effective
**Why**: Good balance of performance and cost
- **Pros**:
  - 10x cheaper than GPT-4o
  - Still very capable for scene analysis
  - Faster response times
- **Cons**: Slightly less accurate than full GPT-4o
- **Implementation**: Change model to `"gpt-4o-mini"`
- **Best for**: High-volume usage, cost-sensitive deployments

### 3. **Claude 3.5 Sonnet (Anthropic)** 🏥 Medical Focus
**Why**: Excellent reasoning for medical scenarios
- **Pros**:
  - Superior reasoning capabilities
  - Better at understanding context
  - Strong medical knowledge
  - Can handle complex multi-step analysis
- **Cons**: Requires Anthropic API, different integration
- **API**: Anthropic Claude API
- **Best for**: Complex medical scenarios requiring deep reasoning

### 4. **Gemini 1.5 Pro (Google)** 🔍 High Detail
**Why**: Excellent for detailed scene analysis
- **Pros**:
  - Very high resolution image understanding
  - Good at detecting small details
  - Free tier available
  - Multimodal capabilities
- **Cons**: Can be slower, different API structure
- **API**: Google Gemini API
- **Best for**: When you need to detect fine details

### 5. **GPT-4 Turbo with Vision** ⚡ Fast & Reliable
**Why**: Proven reliability, good speed
- **Pros**:
  - Well-tested and stable
  - Good balance of speed/accuracy
  - Reliable API
- **Cons**: Older than GPT-4o, less advanced
- **Implementation**: Change model to `"gpt-4-turbo"`
- **Best for**: When stability is priority

## Specialized Medical VLMs

### 6. **Med-PaLM 2 (Google)** 🏥 Medical-Specific
**Why**: Trained specifically on medical data
- **Pros**:
  - Medical domain expertise
  - Better at medical terminology
  - Trained on medical images
- **Cons**: Limited availability, may require special access
- **Best for**: If you can get access, best for medical use cases

### 7. **LLaVA-Med** 🔬 Open Source Medical VLM
**Why**: Open source, medical-focused
- **Pros**:
  - Free/open source
  - Medical domain knowledge
  - Can be fine-tuned
  - Self-hosted option
- **Cons**: Requires more setup, may need fine-tuning
- **GitHub**: microsoft/LLaVA-Med
- **Best for**: Customization, privacy-sensitive deployments

## Quick Comparison Table

| Model | Accuracy | Speed | Cost | Medical Focus | Ease of Use |
|-------|----------|-------|------|---------------|-------------|
| GPT-4o (latest) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | $$$ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| GPT-4o-mini | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | $ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Claude 3.5 Sonnet | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | $$$ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Gemini 1.5 Pro | ⭐⭐⭐⭐ | ⭐⭐⭐ | $$ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| GPT-4 Turbo | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | $$$ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Med-PaLM 2 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | $$$$ | ⭐⭐⭐⭐⭐ | ⭐⭐ |

## Recommended Upgrades

### Option 1: Quick Win (Easiest)
**Upgrade to GPT-4o-2024-11-20 with "high" detail**
```python
# In dedalus_agent.py
model="gpt-4o-2024-11-20"
detail="high"  # Instead of "low"
```
**Impact**: Better accuracy, minimal code changes

### Option 2: Cost Optimization
**Switch to GPT-4o-mini with "high" detail**
```python
model="gpt-4o-mini"
detail="high"
```
**Impact**: 10x cost reduction, still good accuracy

### Option 3: Best Performance
**Use Claude 3.5 Sonnet for complex reasoning**
- Requires Anthropic API integration
- Better for complex medical scenarios
- More expensive but superior reasoning

### Option 4: Hybrid Approach
**Use different models for different scenarios**
- GPT-4o-mini for routine checks (low cost)
- GPT-4o for critical scenarios (high accuracy)
- Claude 3.5 for complex reasoning tasks

## Implementation Examples

### Upgrade to GPT-4o Latest with High Detail
```python
async def _analyze_with_openai(frame_b64: str, context: str) -> str | None:
    try:
        client = AsyncOpenAI(api_key=OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model="gpt-4o-2024-11-20",  # Latest version
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
                                "detail": "high",  # Changed from "low"
                            },
                        },
                    ],
                },
            ],
            max_tokens=200,  # Increased for more detailed analysis
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"[VLM] Error: {e}")
        return None
```

### Add Claude 3.5 Sonnet Option
```python
import anthropic

async def _analyze_with_claude(frame_b64: str, context: str) -> str | None:
    try:
        client = anthropic.AsyncAnthropic(api_key=ANTHROPIC_API_KEY)
        message = await client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=200,
            system=DEDALUS_SCENE_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": context},
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": frame_b64,
                            },
                        },
                    ],
                }
            ],
        )
        return message.content[0].text
    except Exception as e:
        print(f"[VLM] Error: {e}")
        return None
```

### Add Model Selection Logic
```python
async def analyze_scene(
    frame_b64: str,
    scenario_state: str,
    recent_transcript: str,
) -> str | None:
    context = f"Current scenario: {scenario_state}."
    if recent_transcript:
        context += f" User just said: {recent_transcript}"

    # Use best model for critical scenarios
    if scenario_state in ["CPR", "BLEEDING", "CHOKING"]:
        return await _analyze_with_openai(frame_b64, context, model="gpt-4o-2024-11-20", detail="high")
    else:
        return await _analyze_with_openai(frame_b64, context, model="gpt-4o-mini", detail="high")
```

## Cost Comparison (per 1000 images)

| Model | Detail Level | Cost per 1K images |
|-------|--------------|-------------------|
| GPT-4o | low | ~$0.30 |
| GPT-4o | high | ~$2.50 |
| GPT-4o-mini | high | ~$0.25 |
| Claude 3.5 Sonnet | - | ~$3.00 |
| Gemini 1.5 Pro | - | ~$0.20 |

## Performance Tips

1. **Use "high" detail for critical scenarios**
   - Better detection of medical cues
   - Worth the cost increase

2. **Cache similar frames**
   - Skip analysis if scene hasn't changed
   - Already implemented in your code ✓

3. **Adjust analysis frequency**
   - Current: Every 8 seconds
   - For critical scenarios: Every 3-4 seconds
   - For routine: Every 15 seconds

4. **Use structured outputs**
   - Request JSON format for easier parsing
   - Better for downstream processing

5. **Prompt engineering**
   - Medical-specific prompts improve accuracy
   - Include context about emergency types

## Recommended Next Steps

1. **Immediate**: Upgrade to GPT-4o-2024-11-20 with "high" detail
2. **Short-term**: Test GPT-4o-mini for cost optimization
3. **Long-term**: Consider Claude 3.5 Sonnet for complex reasoning
4. **Future**: Fine-tune LLaVA-Med on your specific use cases

## Testing Different Models

Create a model comparison script:
```python
async def compare_models(frame_b64: str, context: str):
    results = {}
    
    # Test GPT-4o
    results['gpt-4o'] = await _analyze_with_openai(frame_b64, context, "gpt-4o", "high")
    
    # Test GPT-4o-mini
    results['gpt-4o-mini'] = await _analyze_with_openai(frame_b64, context, "gpt-4o-mini", "high")
    
    # Compare results
    return results
```

## Conclusion

**Best immediate upgrade**: GPT-4o-2024-11-20 with "high" detail
**Best cost/performance**: GPT-4o-mini with "high" detail  
**Best for complex reasoning**: Claude 3.5 Sonnet
**Best for medical domain**: Med-PaLM 2 (if available)

Start with GPT-4o-2024-11-20 + "high" detail for immediate improvement, then test GPT-4o-mini for cost optimization.
