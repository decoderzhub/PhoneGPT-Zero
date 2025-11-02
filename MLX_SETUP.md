# MLX-LM Integration for PhoneGPT

PhoneGPT now uses Apple's MLX framework for running local large language models directly on your iPhone 15 Pro Max.

## What's New

- **MLX-Swift Integration**: Uses Apple's official MLX framework optimized for Apple Silicon
- **High-Quality LLM**: Default model is Qwen2.5-3B-Instruct (4-bit quantized)
- **Still Private**: All processing happens on-device
- **Better Responses**: Significantly improved quality compared to basic Neural Engine
- **RAG Support**: Full integration with existing document retrieval system

## How It Works

### First Launch

1. **Model Download**: On first launch, the app will automatically download the Qwen2.5-3B-Instruct model (~2GB)
2. **Progress Tracking**: You'll see download progress in the console
3. **One-Time Setup**: The model is cached locally and only needs to be downloaded once

### Supported Models

The app can use any MLX-compatible model from Hugging Face. Popular options:

- `mlx-community/Qwen2.5-3B-Instruct-4bit` (default, balanced quality/speed)
- `mlx-community/Phi-3.5-mini-instruct-4bit` (faster, smaller)
- `mlx-community/Mistral-7B-Instruct-v0.3-4bit` (higher quality, slower)
- `mlx-community/Llama-3.2-3B-Instruct-4bit` (Meta's Llama)

### Switching Models

To switch models, you can call:
```swift
await modelManager.switchModel(to: "mlx-community/Phi-3.5-mini-instruct-4bit")
```

## Performance

**iPhone 15 Pro Max Performance:**
- Tokens per second: 15-30 (depending on model)
- First token latency: ~500ms
- Memory usage: ~3-4GB for 3B models

**Model Sizes:**
- 3B models (4-bit): ~2GB
- 7B models (4-bit): ~4GB
- Larger models may be slower but provide better quality

## RAG Integration

The MLX model works seamlessly with your document retrieval system:

1. **Document Search**: Your query searches through imported documents
2. **Context Building**: Relevant chunks are extracted and formatted
3. **LLM Generation**: MLX model generates response using context
4. **Grammar Refinement**: Optional post-processing for fluency

## Technical Details

### Architecture

- **MLX Framework**: Apple's ML framework for Apple Silicon
- **MLXLLM**: High-level LLM interface from mlx-swift-examples
- **Tokenizer**: BPE tokenizer for text encoding/decoding
- **Inference**: Runs on Neural Engine + GPU + CPU for optimal performance

### Generation Parameters

- Temperature: 0.7 (controls randomness)
- Top-P: 0.9 (nucleus sampling)
- Repetition Penalty: 1.1 (reduces repetition)
- Max Tokens: 512 (adjustable)

### Prompt Format

Uses ChatML format for Qwen models:
```
<|im_start|>system
You are a helpful AI assistant...
<|im_end|>
<|im_start|>user
What is the capital of France?
<|im_end|>
<|im_start|>assistant
```

## Troubleshooting

### Model Won't Download
- Check internet connection
- Ensure sufficient storage (~3-5GB free)
- Try switching to WiFi for large downloads

### Slow Performance
- Close other apps to free up memory
- Use smaller models (3B instead of 7B)
- Reduce max_tokens parameter

### Out of Memory
- Use 4-bit quantized models only
- Avoid models larger than 7B
- Restart the app to clear cache

## Development

### Adding New Models

1. Find an MLX-compatible model on Hugging Face (search "mlx-community")
2. Note the model ID (e.g., "mlx-community/ModelName-4bit")
3. Update the `defaultModelID` in MLXModelManager.swift
4. Rebuild and run

### Custom Model Configuration

```swift
let generateParameters = GenerateParameters(
    temperature: 0.7,      // Lower = more focused
    topP: 0.9,            // Nucleus sampling threshold
    repetitionPenalty: 1.1 // Higher = less repetition
)
```

## Resources

- [MLX Swift Repository](https://github.com/ml-explore/mlx-swift)
- [MLX Swift Examples](https://github.com/ml-explore/mlx-swift-examples)
- [MLX Community Models](https://huggingface.co/mlx-community)
- [Apple MLX Blog Post](https://www.swift.org/blog/mlx-swift/)
