# MentraOS Integration Guide

How PhoneGPT communicates with Even Realities glasses via MentraOS

## Architecture Overview

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  PhoneGPT    │         │   Webhook    │         │   MentraOS   │
│  iOS App     │         │   Server     │         │   iOS App    │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │ 1. Opens MentraOS      │                        │
       │ mentraos://connect     │                        │
       │ ──────────────────────────────────────────────► │
       │                        │                        │
       │ 2. Polls for events    │                        │
       │ GET /events?since=0    │                        │
       │ ───────────────────►   │                        │
       │                        │                        │
       │                        │ 3. User speaks         │
       │                        │ POST /webhook          │
       │                        │ {type: voice_input}    │
       │                        │ ◄────────────────────── │
       │                        │                        │
       │ 4. Gets voice event    │                        │
       │ ◄─────────────────────  │                        │
       │                        │                        │
       │ 5. Processes with AI   │                        │
       │ (MLX/Llama)           │                        │
       │                        │                        │
       │ 6. Sends response      │                        │
       │ mentraos://display     │                        │
       │ ?text=Response         │                        │
       │ ──────────────────────────────────────────────► │
       │                        │                        │
       │                        │ 7. Displays on glasses │
       │                        │                    👓  │
```

## Communication Methods

### 1. PhoneGPT → MentraOS (URL Schemes)

PhoneGPT uses URL schemes to send commands to MentraOS:

```swift
// Display text on glasses
mentraos://display?text=Hello%20World

// Clear display
mentraos://clear

// Request voice input
mentraos://voice-capture

// Connect/initialize
mentraos://connect
```

### 2. MentraOS → Webhook Server (HTTP POST)

MentraOS posts events to webhook:

```json
POST https://phonegpt-webhook.systemd.diskstation.me/webhook
Content-Type: application/json

{
  "type": "voice_input",
  "data": {
    "transcript": "What's the weather today?"
  },
  "device_id": "even_realities_001",
  "timestamp": "2025-11-03T10:30:00Z"
}
```

### 3. Webhook Server → PhoneGPT (HTTP Polling)

PhoneGPT polls webhook every 2 seconds:

```swift
GET https://phonegpt-webhook.systemd.diskstation.me/events?since=0

Response:
{
  "events": [
    {
      "type": "voice_input",
      "data": {"transcript": "What's the weather?"},
      "timestamp": "2025-11-03T10:30:00Z"
    }
  ],
  "count": 1,
  "last_index": 1
}
```

## Event Types

### From MentraOS to Webhook

| Event Type | Description | Data Fields |
|------------|-------------|-------------|
| `app_activated` | User opened PhoneGPT in MentraOS | `device_id` |
| `app_deactivated` | User closed PhoneGPT | `device_id` |
| `voice_input` | User spoke into glasses | `transcript` (string) |
| `gesture` | User made gesture | `gesture_type` (string) |
| `connection_status` | Glasses connected/disconnected | `connected` (bool) |

### Gesture Types

| Gesture | Value | Use Case |
|---------|-------|----------|
| Single tap | `tap_once` | Repeat last response |
| Double tap | `tap_twice` | Start new query |
| Swipe up | `swipe_up` | Next item |
| Swipe down | `swipe_down` | Previous item |
| Swipe left | `swipe_left` | Cancel |
| Swipe right | `swipe_right` | Confirm |

## Complete Flow Example

### User asks: "What's the weather?"

1. **User activates PhoneGPT in MentraOS**
   ```json
   POST /webhook
   {
     "type": "app_activated",
     "device_id": "even_001"
   }
   ```

2. **PhoneGPT polls and sees activation**
   ```
   GET /events?since=0
   → Receives app_activated event
   → Starts active session
   ```

3. **User speaks: "What's the weather?"**
   ```json
   POST /webhook
   {
     "type": "voice_input",
     "data": {"transcript": "What's the weather?"}
   }
   ```

4. **PhoneGPT polls and receives voice input**
   ```
   GET /events?since=1
   → Receives voice_input event
   → Extracts: "What's the weather?"
   ```

5. **PhoneGPT processes with AI**
   ```swift
   // In GlassesAssistantViewModel
   let response = await chatViewModel.sendMessage(transcript)
   // MLX processes locally: "Weather: 72°F, sunny"
   ```

6. **PhoneGPT sends response to glasses**
   ```
   mentraos://display?text=Weather:%2072°F,%20sunny
   → MentraOS displays on glasses
   → User sees response through lenses
   ```

## MentraOS Integration Form

When submitting your app to MentraOS:

### Required Information

```
App Identifier: phonegpt-ai

App Name: PhoneGPT AI Assistant

Description:
Local AI assistant powered by PhoneGPT with complete privacy.
Voice-activated responses using on-device Llama models via MLX.
No cloud processing - everything runs locally on your iPhone.

Category: Productivity / AI Assistant

App Type: Background App (runs when activated)

Permissions Required:
✅ Microphone Access
✅ Voice Transcripts
❌ Location
❌ Camera
❌ Contacts

Hardware Requirements:
None - works with iPhone only

Onboarding Instructions:
1. Install PhoneGPT on iPhone
2. Pair Even Realities glasses with MentraOS
3. Open PhoneGPT app → Devices → Even Realities G1
4. Tap "Launch AI Assistant"
5. In MentraOS, activate PhoneGPT app
6. Speak your question - AI responds instantly

Server URL:
https://phonegpt-webhook.systemd.diskstation.me/webhook

Server Type: Webhook

Authentication: None (can add Bearer token if needed)

Icon: [Upload PhoneGPTAppIcon.png]

Screenshots:
- Main chat interface
- Glasses connection screen
- Example conversation

Support Email: support@phonegpt.com

Privacy Policy URL: https://phonegpt.com/privacy

Terms of Service URL: https://phonegpt.com/terms
```

## Testing Before Submission

### 1. Test Webhook Server

```bash
# Health check
curl https://phonegpt-webhook.systemd.diskstation.me/health

# Post test event
curl -X POST https://phonegpt-webhook.systemd.diskstation.me/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "voice_input",
    "data": {"transcript": "Test"},
    "device_id": "test"
  }'

# Check events
curl https://phonegpt-webhook.systemd.diskstation.me/events?since=0
```

### 2. Test iOS App Polling

1. Open PhoneGPT
2. Go to Devices → Even Realities G1
3. Check logs for:
   ```
   🔄 Started polling webhook every 2 seconds
   ```

3. Post a test event to webhook
4. Check if app receives it within 2 seconds

### 3. Test URL Scheme (Simulated)

```swift
// In iOS app, test opening MentraOS
if let url = URL(string: "mentraos://display?text=Test") {
    UIApplication.shared.open(url)
}

// Should attempt to open MentraOS (will show error if not installed)
```

## Debugging

### Enable Detailed Logging

In `MentraOSService.swift`:

```swift
func checkForEvents() async {
    guard let url = URL(string: "\(webhookURL)/events?since=\(lastEventIndex)") else {
        print("❌ Invalid webhook URL")
        return
    }

    print("🔍 Polling: \(url.absoluteString)")

    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status: \(httpResponse.statusCode)")
        }

        let responseString = String(data: data, encoding: .utf8)
        print("📥 Response: \(responseString ?? "empty")")

        let response = try JSONDecoder().decode(EventsResponse.self, from: data)
        print("✅ Decoded \(response.events.count) events")

        // ... rest of function
    } catch {
        print("❌ Polling error: \(error)")
        print("❌ Error details: \(error.localizedDescription)")
    }
}
```

### Monitor Webhook Server

```bash
# Watch logs in real-time
docker logs -f phonegpt-webhook

# Should see:
# INFO: Started polling...
# INFO: Received event: voice_input
# INFO: Sending to glasses...
```

### Check Network Connectivity

```bash
# From iPhone (via Safari or Network Utility)
https://phonegpt-webhook.systemd.diskstation.me/health

# Should return JSON:
# {"status":"healthy",...}
```

## Security Considerations

### Add Authentication (Optional)

If you want to secure the webhook:

1. **Update webhook server** (`main.py`):
```python
from fastapi import Header, HTTPException

WEBHOOK_SECRET = "your_secret_token_here"

@app.post("/webhook")
async def mentraos_webhook(
    event: WebhookEvent,
    x_webhook_secret: str = Header(None)
):
    if x_webhook_secret != WEBHOOK_SECRET:
        raise HTTPException(401, "Unauthorized")

    # ... rest of function
```

2. **Configure in MentraOS submission**:
```
Custom Headers:
X-Webhook-Secret: your_secret_token_here
```

### Rate Limiting

Add to protect against abuse:

```bash
pip install slowapi

# In main.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/webhook")
@limiter.limit("100/minute")
async def mentraos_webhook(...):
    # ... function code
```

## Troubleshooting Common Issues

### Polling not working

- Check webhook URL is correct
- Verify SSL certificate is valid
- Test with curl from iPhone's network
- Check iOS app has network permissions

### Events not received

- Verify MentraOS is posting to webhook
- Check webhook logs for incoming POSTs
- Test endpoint manually with curl

### Display not showing on glasses

- Verify URL scheme format
- Check MentraOS app is installed
- Test simple text first: `mentraos://display?text=Test`

## Next Steps

1. ✅ Deploy webhook server to Synology
2. ✅ Test all endpoints
3. ⏳ Submit integration form to MentraOS
4. ⏳ Wait for approval (usually 1-2 weeks)
5. ⏳ Test with real MentraOS integration
6. ⏳ Iterate based on feedback

## Support Resources

- MentraOS Developer Portal: [URL when available]
- PhoneGPT GitHub: https://github.com/decoderzhub/PhoneGPT-Zero
- Webhook Server: https://phonegpt-webhook.systemd.diskstation.me
