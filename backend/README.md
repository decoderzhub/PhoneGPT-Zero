# PhoneGPT MentraOS Webhook Server

FastAPI backend server that bridges communication between MentraOS smart glasses and the PhoneGPT iOS app.

## Overview

This webhook server acts as a communication bridge:
- **MentraOS → Server**: Receives events (voice input, gestures, app activation)
- **Server → PhoneGPT**: Provides events via polling endpoint
- **PhoneGPT → Server**: Sends display requests

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run server
python main.py

# Or with uvicorn
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server will be available at: `http://localhost:8000`

### Docker

```bash
# Build image
docker build -t phonegpt-webhook .

# Run container
docker run -p 8000:8000 phonegpt-webhook
```

## Deployment Options

### Option 1: Deploy to Your Synology NAS (Recommended for You)

Since you want to use `https://phoneGPT-webhook.systemd.diskstation.me`:

**Requirements:**
- Synology NAS with Docker support
- Port forwarding configured
- SSL certificate (Let's Encrypt via Synology)

**Steps:**

1. **Enable Docker on Synology:**
   - Open Package Center
   - Install Docker package

2. **Upload files to NAS:**
   ```bash
   # Via SSH or File Station, create folder:
   /docker/phonegpt-webhook/

   # Upload: main.py, requirements.txt, Dockerfile
   ```

3. **Build and run in Docker:**
   ```bash
   # SSH into Synology
   cd /volume1/docker/phonegpt-webhook

   # Build image
   sudo docker build -t phonegpt-webhook .

   # Run container
   sudo docker run -d \
     --name phonegpt-webhook \
     -p 8000:8000 \
     --restart unless-stopped \
     phonegpt-webhook
   ```

4. **Configure Reverse Proxy in Synology:**
   - Control Panel → Application Portal → Reverse Proxy
   - Create new rule:
     - Source:
       - Protocol: HTTPS
       - Hostname: `phonegpt-webhook.systemd.diskstation.me`
       - Port: 443
     - Destination:
       - Protocol: HTTP
       - Hostname: localhost
       - Port: 8000
   - Enable HSTS and HTTP/2

5. **Configure SSL Certificate:**
   - Control Panel → Security → Certificate
   - Add new certificate for `phonegpt-webhook.systemd.diskstation.me`
   - Use Let's Encrypt

6. **Update DDNS (if needed):**
   - Control Panel → External Access → DDNS
   - Add subdomain: `phonegpt-webhook`

### Option 2: Railway.app (Alternative - Easiest Cloud Option)

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Deploy
railway up

# Get URL
railway domain
```

### Option 3: Render.com (Free Tier Available)

1. Create account at render.com
2. New Web Service → Connect this repository
3. Configure:
   - Name: phonegpt-webhook
   - Environment: Python
   - Build: `pip install -r requirements.txt`
   - Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`

## API Endpoints

### Health & Status

```bash
# Health check
GET /health

# Server stats
GET /stats

# Active sessions
GET /sessions
```

### Webhook (MentraOS → Server)

```bash
# MentraOS posts events here
POST /webhook
Content-Type: application/json

{
  "type": "voice_input",
  "data": {
    "transcript": "What's the weather today?"
  },
  "device_id": "even_realities_001"
}
```

**Event Types:**
- `app_activated` - User opened PhoneGPT in MentraOS
- `app_deactivated` - User closed app
- `voice_input` - Voice command received
- `gesture` - Gesture detected (tap, swipe)
- `connection_status` - Connection state changed

### Polling (PhoneGPT → Server)

```bash
# PhoneGPT polls for new events
GET /events?since=0&limit=100

Response:
{
  "events": [
    {
      "type": "voice_input",
      "data": {"transcript": "Hello"},
      "timestamp": "2025-11-03T10:30:00Z",
      "device_id": "even_realities_001"
    }
  ],
  "count": 1,
  "last_index": 1
}
```

### Display Request (PhoneGPT → Server)

```bash
# Request text display on glasses
POST /display
Content-Type: application/json

{
  "text": "Weather: 72°F, Sunny",
  "device_id": "even_realities_001",
  "duration": 5
}
```

## Testing

### Test webhook endpoint:

```bash
curl -X POST https://phonegpt-webhook.systemd.diskstation.me/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "voice_input",
    "data": {"transcript": "Test message"},
    "device_id": "test_device"
  }'
```

### Poll for events:

```bash
curl https://phonegpt-webhook.systemd.diskstation.me/events?since=0
```

### Check health:

```bash
curl https://phonegpt-webhook.systemd.diskstation.me/health
```

## Integration with PhoneGPT App

The iOS app needs to:

1. **Poll for events** (every 2 seconds when active):
   ```swift
   GET /events?since={lastEventIndex}
   ```

2. **Handle received events**:
   - `voice_input` → Process with AI
   - `gesture` → Execute quick actions
   - `app_activated` → Prepare session

3. **Send responses**:
   - Use URL scheme: `mentraos://display?text=...`
   - Or POST to `/display` endpoint

## MentraOS Integration Form

When submitting to MentraOS:

```
Server URL: https://phonegpt-webhook.systemd.diskstation.me/webhook
App Identifier: phonegpt-ai
App Name: PhoneGPT AI Assistant
Permissions: ✅ Microphone + Transcripts
```

## Security Considerations

For production:

1. **Add authentication:**
   ```python
   # In main.py
   WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET")

   @app.post("/webhook")
   async def webhook(event: WebhookEvent, x_webhook_secret: str = Header(None)):
       if x_webhook_secret != WEBHOOK_SECRET:
           raise HTTPException(401, "Unauthorized")
   ```

2. **Rate limiting:**
   ```bash
   pip install slowapi
   ```

3. **Use Redis for event queue:**
   ```bash
   pip install redis
   ```

## Monitoring

Check logs:
```bash
# Docker logs
docker logs -f phonegpt-webhook

# Or direct log file
tail -f /var/log/phonegpt-webhook.log
```

## Troubleshooting

**Connection refused:**
- Check if server is running: `curl http://localhost:8000/health`
- Verify port forwarding
- Check firewall rules

**Events not appearing:**
- Check `/stats` endpoint for event counts
- Verify MentraOS is posting to correct URL
- Check server logs for errors

**SSL certificate issues:**
- Verify certificate is valid: `openssl s_client -connect phonegpt-webhook.systemd.diskstation.me:443`
- Renew Let's Encrypt certificate in Synology

## Support

For issues or questions:
- Check logs first
- Verify all endpoints with curl
- Test with simple POST request to /webhook
