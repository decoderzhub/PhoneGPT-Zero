# TypeScript Backend Quick Start

## Setup (One Time)

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Create .env file:**
   ```bash
   cp .env.example .env
   ```

4. **Edit .env with your MentraOS credentials:**
   ```bash
   nano .env
   ```
   
   Required values:
   - `PACKAGE_NAME`: Your app package name (e.g., `com.codeofhonor.phonegpt`)
   - `MENTRAOS_API_KEY`: Get from [console.mentra.glass](https://console.mentra.glass)
   - `PORT`: 3000 (or your preferred port)

## Run Development Server

```bash
npm run dev
```

Or use the convenience script:

```bash
./start.sh
```

## What You'll See

```
🚀 PHONEGPT MENTRAOS SERVER STARTED
==================================================
   Package: com.codeofhonor.phonegpt
   Port: 3000
   Endpoints:
   - GET /health
   - GET /events (PhoneGPT polling)
   - POST /display (PhoneGPT display)
   - GET /dashboard (Web UI)
   - MentraOS webhooks (handled by SDK)
==================================================

🔵 NEW SESSION STARTED
   Session ID: user@example.com-com.yourapp
   User ID: user@example.com

🎤 VOICE INPUT RECEIVED
   Transcript: "What's the weather?"
```

## Expose with ngrok

In a separate terminal:

```bash
ngrok http --url=<YOUR_STATIC_URL> 3000
```

Update your webhook URL in [MentraOS Console](https://console.mentra.glass).

## Web Dashboard

Once running, visit: **http://localhost:3000/dashboard**

Test display and monitor active sessions.

## Endpoints for PhoneGPT iOS App

- `GET /events` - Poll for new events (voice input)
- `POST /display` - Send AI responses to glasses
- `GET /sessions` - View active sessions
- `GET /stats` - Server statistics

## Next Steps

1. Activate PhoneGPT app in MentraOS phone app
2. Speak to your glasses
3. Watch transcriptions appear in server logs
4. iOS app polls `/events` and gets voice input
5. iOS app sends AI response via `/display`
6. Response appears on glasses!
