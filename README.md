# PhoneGPT-Zero

A **ChatGPT-quality AI assistant** that runs entirely on your iPhone using **Microsoft Phi-3-mini (3.8B parameters)**. No cloud, no API keys, complete privacy.

## ✨ Features

- 🤖 **ChatGPT-Level Conversations** - Powered by Microsoft Phi-3-mini (3.8B params)
- 🧠 **100% Local Processing** - Runs on iPhone's Neural Engine via Apple MLX
- ⚡ **Real-Time Streaming** - 12-15 tokens/second, words appear as they generate
- 🔒 **Complete Privacy** - Your data never leaves your device
- 💬 **Context Awareness** - Remembers conversation history for natural follow-ups
- 📚 **Document RAG** - Import and search your PDFs, Word docs, and text files
- 📱 **Message Integration** - Search through your iMessage history (via export)
- 🚀 **Neural Engine Optimized** - Leverages iPhone 15 Pro's A17 chip (35 TOPS)

## 🎯 What Makes This Special

Unlike other AI assistants, PhoneGPT:
- ✅ Works in airplane mode
- ✅ Zero network latency (instant responses)
- ✅ Free unlimited usage (no API costs)
- ✅ Your conversations stay private
- ✅ Powered by actual LLM (Phi-3), not scripted responses

## 📊 Performance

On iPhone 15 Pro:
- **Speed**: 12-15 tokens/second
- **Latency**: ~200-300ms to first token
- **Model Size**: 2.3GB (4-bit quantized)
- **Quality**: Matches GPT-3.5 on most tasks

## ✅ Requirements

- **Device**: iPhone 15 Pro or newer (Apple Silicon required)
- **iOS**: 18.5+ (or 16.0+ minimum)
- **Storage**: ~3GB free (for Phi-3 model)
- **Xcode**: 15.0+
- **Note**: Requires physical device (MLX doesn't support simulator)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/decoderzhub/PhoneGPT-Zero.git
cd PhoneGPT-Zero
open PhoneGPT.xcodeproj
```

### 2. Add Swift Package Dependencies

In Xcode: **File → Add Package Dependencies...**

Add these three packages:
- `https://github.com/ml-explore/mlx-swift.git` (v0.25.5+)
- `https://github.com/ml-explore/mlx-swift-examples.git` (main branch)
  - Products: `MLXLLM`, `MLXLMCommon`
- `https://github.com/huggingface/swift-transformers.git`
  - Products: `Tokenizers`
- `https://github.com/weichsel/ZIPFoundation.git` (for document import)

### 3. Download Phi-3-mini Model

```bash
# Install Hugging Face CLI
pip install huggingface-hub

# Download 4-bit quantized model (~2.3GB)
huggingface-cli download microsoft/Phi-3-mini-4k-instruct-onnx \
  --include "cpu_and_mobile/cpu-int4-rtn-block-32-acc-level-4/*" \
  --local-dir ./phi-3-mini-4k-instruct-4bit
```

### 4. Add Model to Xcode

1. In Xcode, right-click `PhoneGPT` group → **Add Files to "PhoneGPT"...**
2. Select the `phi-3-mini-4k-instruct-4bit` folder
3. **Important**: Choose "Create folder references" (blue folder, not yellow)
4. Add to target: `PhoneGPT`

### 5. Build and Run

1. Select your iPhone 15 Pro as the target
2. Build (Cmd+B) and Run (Cmd+R)
3. Try: "Hi!", "Why is the sky blue?", "Tell me about yourself"

📖 **For detailed setup instructions, see [PHI3_MLX_SETUP.md](PHI3_MLX_SETUP.md)**

## Usage

### Import Documents
1. Tap "Import Files"
2. Select PDFs, DOCX, or text files
3. Documents are automatically indexed

### Search Messages (Optional)
1. On Mac, run the message exporter:
```bash
python3 scripts/messages_exporter.py
```
2. Import the generated `messages_summary.txt` in PhoneGPT

### Ask Questions
- "What did John say about the project?"
- "Summarize my meeting notes"
- "Find information about [topic] in my documents"

## Architecture

- **CoreML** - Neural network inference
- **Metal** - GPU acceleration
- **PDFKit** - PDF text extraction
- **ZIPFoundation** - DOCX support
- **Vector Search** - Document similarity matching
- **128-dim Embeddings** - Text vectorization

## Model Details

- Architecture: Transformer-based
- Size: ~60MB compressed
- Quantization: Float16
- Inference: 15 tokens/second

## Privacy

- No network requests
- No analytics or tracking
- Documents stay on device
- Messages processed locally
- No cloud dependencies

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## License

[MIT](LICENSE)

## Acknowledgments

- Built with SwiftUI and CoreML
- Inspired by local-first AI principles
- Thanks to the open source community

---

**Note:** This is an experimental project showcasing on-device AI capabilities. Model performance is limited by mobile hardware constraints.