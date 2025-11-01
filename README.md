# PhoneGPT-Zero

A local AI assistant that runs entirely on your iPhone's Neural Engine. No cloud, no API keys, complete privacy.

## Features

- 🧠 **100% Local Processing** - Runs on iPhone's Neural Engine
- 🔒 **Complete Privacy** - Your data never leaves your device
- 📚 **Document RAG** - Import and search your PDFs, Word docs, and text files
- 💬 **Message Integration** - Search through your iMessage history (via export)
- ⚡ **Offline Operation** - Works without internet connection
- 🚀 **35 TOPS Performance** - Leverages iPhone 15 Pro's A17 chip

## Requirements

- iPhone 15 Pro or iPhone 15 Pro Max (A17 Pro chip)
- iOS 17.0+
- Xcode 15.0+
- ~100MB free storage

## Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/PhoneGPT-Zero.git
```

2. Open in Xcode:
```bash
cd PhoneGPT-Zero
open PhoneGPT.xcodeproj
```

3. Install dependencies:
   - Add ZIPFoundation via Swift Package Manager:
     - File → Add Package Dependencies
     - Enter: `https://github.com/weichsel/ZIPFoundation`

4. Build and run on your iPhone 15 Pro

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