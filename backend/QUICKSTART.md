# Quick Start Guide - MentraOS Integration

Get PhoneGPT running with MentraOS in 10 minutes.

## Prerequisites

- Node.js 18+ installed
- MentraOS app on your phone
- Glasses paired with MentraOS

## Step 1: Register App in MentraOS Console

1. Go to https://console.mentra.glass
2. Sign in with your MentraOS account
3. Click "Create App"
4. Fill in:
   - Package Name: `com.codeofhonor.phonegpt`
   - App Name: `PhoneGPT AI Assistant`
   - Public URL: (use ngrok URL from Step 3)
5. Add Permission: MICROPHONE
6. **Copy your API Key**

## Step 2: Configure Environment

```bash
cd backend
cp .env.example .env
nano .env
```

Add your API key:
```env
MENTRAOS_API_KEY=msk_live_your_key_here
PACKAGE_NAME=com.codeofhonor.phonegpt
PORT=3000
API_PORT=3001
```

## Step 3: Install & Run

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev
```

You should see:
```
🚀 STARTING PHONEGPT MENTRAOS SERVER
✅ MentraOS server started on port 3000
✅ API server started on port 3001
⏳ Waiting for MentraOS connections...
```

## Step 4: Expose with ngrok

In a new terminal:

```bash
# Install ngrok
brew install ngrok  # macOS

# Get a static domain from ngrok.com dashboard

# Run ngrok
ngrok http --url=your-static-url.ngrok-free.app 3000
```

Copy the ngrok URL (e.g., `https://your-static-url.ngrok-free.app`)

## Step 5: Update MentraOS Console

1. Go back to https://console.mentra.glass
2. Edit your app
3. Update Public URL to your ngrok URL
4. Save changes

## Step 6: Test Connection

1. Open **MentraOS app** on your phone
2. You should see **"PhoneGPT AI Assistant"** in inactive apps
3. **Toggle it ON**

Check your server logs - you should see:
```
🔵 ================================
📱 NEW SESSION STARTED
   Session ID: sess_xxxxx
   User ID: user_xxxxx
================================
💬 Displayed welcome message on glasses
```

## Step 7: Test Voice Input

1. **Speak into your glasses**: "What's the weather?"

Server logs should show:
```
🎤 ================================
VOICE INPUT RECEIVED
   Transcript: "What's the weather?"
================================
```

2. **Test PhoneGPT iOS app polling:**

Open Xcode, run PhoneGPT, go to Glasses Assistant view.

In logs you should see:
```
🔄 Started polling webhook every 2 seconds
📨 Received event: voice_input
```

## Troubleshooting

### Server won't start
- Check you have `MENTRAOS_API_KEY` in `.env`
- Verify API key is correct from console.mentra.glass
- Check ports 3000 and 3001 are free

### No connection from MentraOS
- Verify ngrok is running
- Check Public URL in console.mentra.glass matches ngrok URL
- Try restarting the app in MentraOS (toggle off/on)

### Voice not working
- Check microphone permission is added in console.mentra.glass
- Verify glasses are paired and connected
- Check server logs for voice input

### iOS app not receiving events
- Verify webhook URL in `MentraOSService.swift`:
  ```swift
  private let webhookURL = "http://YOUR_COMPUTER_IP:3001"
  ```
- For ngrok, use: `https://your-static-url.ngrok-free.app:3001`

## Test Endpoints

```bash
# Health check
curl http://localhost:3001/health

# Check events
curl http://localhost:3001/events?since=0

# Check active sessions
curl http://localhost:3001/sessions

# Stats
curl http://localhost:3001/stats
```

## Next Steps

Once working locally:
1. Deploy to Synology NAS (see DEPLOYMENT_SYNOLOGY.md)
2. Update iOS app with production webhook URL
3. Test end-to-end voice commands
4. Share app with testers

## Quick Reference

**Server Logs:**
```bash
npm run dev  # Watch logs in real-time
```

**Key Ports:**
- 3000: MentraOS SDK endpoint
- 3001: API endpoint for PhoneGPT iOS app

**Key Files:**
- `src/index.ts` - Main server code
- `.env` - Configuration
- `package.json` - Dependencies

**Key URLs:**
- MentraOS Console: https://console.mentra.glass
- ngrok Dashboard: https://dashboard.ngrok.com

**Deployment:**
See `DEPLOYMENT_SYNOLOGY.md` for production deployment to your NAS.
