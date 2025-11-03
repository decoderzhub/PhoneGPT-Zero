# Quick Start Guide

Get the PhoneGPT webhook server running in 5 minutes.

## Option 1: Local Development (Fastest)

### Prerequisites
- Python 3.11+ installed
- pip installed

### Steps

```bash
# 1. Navigate to backend folder
cd backend

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run server
python main.py

# 4. Test in another terminal
curl http://localhost:8000/health
```

Server is now running at `http://localhost:8000`

## Option 2: Docker (Recommended)

### Prerequisites
- Docker installed

### Steps

```bash
# 1. Navigate to backend folder
cd backend

# 2. Build and run with docker-compose
docker-compose up -d

# 3. Check logs
docker-compose logs -f

# 4. Test
curl http://localhost:8000/health
```

Server is now running at `http://localhost:8000`

## Option 3: Docker Manual

```bash
# Build image
docker build -t phonegpt-webhook .

# Run container
docker run -d \
  --name phonegpt-webhook \
  -p 8000:8000 \
  phonegpt-webhook

# Check logs
docker logs -f phonegpt-webhook

# Test
curl http://localhost:8000/health
```

## Testing

### Run automated tests

```bash
# Make executable
chmod +x test_webhook.sh

# Run tests (local)
./test_webhook.sh http://localhost:8000

# Run tests (production)
./test_webhook.sh https://phonegpt-webhook.systemd.diskstation.me
```

### Manual tests

```bash
# 1. Health check
curl http://localhost:8000/health

# 2. Post voice input
curl -X POST http://localhost:8000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "voice_input",
    "data": {"transcript": "Test message"},
    "device_id": "test"
  }'

# 3. Get events
curl http://localhost:8000/events?since=0

# 4. Check stats
curl http://localhost:8000/stats
```

## API Endpoints

Once running, visit:
- Documentation: http://localhost:8000/docs (Interactive Swagger UI)
- Alternative docs: http://localhost:8000/redoc
- Health: http://localhost:8000/health

## Update iOS App for Local Testing

In `MentraOSService.swift`, change:

```swift
// Production
private let webhookURL = "https://phonegpt-webhook.systemd.diskstation.me"

// Local testing
private let webhookURL = "http://localhost:8000"  // Won't work on real device
private let webhookURL = "http://YOUR_COMPUTER_IP:8000"  // Use this instead
```

Find your computer's IP:

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'

# Windows
ipconfig
```

Then use: `http://192.168.1.XXX:8000`

## Stop Server

### Python
Press `Ctrl+C`

### Docker Compose
```bash
docker-compose down
```

### Docker Manual
```bash
docker stop phonegpt-webhook
docker rm phonegpt-webhook
```

## Deploy to Production

Once local testing works, see:
- **DEPLOYMENT_SYNOLOGY.md** - Deploy to your Synology NAS
- **MENTRAOS_INTEGRATION.md** - Submit to MentraOS

## Troubleshooting

### Port 8000 already in use

```bash
# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process or use different port
docker run -p 8001:8000 phonegpt-webhook
```

### Python dependencies fail

```bash
# Update pip
pip install --upgrade pip

# Install with verbose output
pip install -r requirements.txt -v
```

### Docker build fails

```bash
# Clean and rebuild
docker system prune -a
docker build --no-cache -t phonegpt-webhook .
```

### Can't access from iPhone

Make sure:
1. iPhone and computer on same WiFi
2. Using computer's IP (not localhost)
3. Firewall allows port 8000
4. Server is running: `curl http://localhost:8000/health`

## Next Steps

1. ✅ Get server running locally
2. ✅ Test with curl/test script
3. ✅ Update iOS app to use local URL
4. ✅ Test iOS app polling
5. ⏭️ Deploy to Synology (see DEPLOYMENT_SYNOLOGY.md)
6. ⏭️ Submit to MentraOS (see MENTRAOS_INTEGRATION.md)

## Support

If stuck:
1. Check server logs: `docker logs phonegpt-webhook`
2. Verify health endpoint works
3. Test with curl before testing with app
4. Review README.md for detailed documentation
