# PhoneGPT MentraOS TypeScript Backend

TypeScript backend that bridges PhoneGPT iOS app with MentraOS smart glasses using the official `@mentra/sdk`.

## Features

- **MentraOS Integration**: Real-time voice transcription from glasses
- **PhoneGPT Integration**: Event polling and display endpoints for iOS app
- **Session Management**: Track multiple active glasses sessions
- **Web Dashboard**: Monitor sessions and test display at `/dashboard`

## Prerequisites

- Node.js v18 or later
- npm or bun
- MentraOS account and API key from [console.mentra.glass](https://console.mentra.glass)
- Registered app in MentraOS Console

## Quick Start

### 1. Install Dependencies

Using npm:
```bash
npm install
```

Using bun:
```bash
bun install
```

### 2. Configure Environment

```bash
# Copy example env file
cp .env.example .env

# Edit .env with your credentials
nano .env
```

Required environment variables:
- `PACKAGE_NAME`: Your app package name from MentraOS Console (e.g., `com.codeofhonor.phonegpt`)
- `MENTRAOS_API_KEY`: API key from MentraOS Console
- `PORT`: Server port (default: 3000)

### 3. Run Development Server

Using npm:
```bash
npm run dev
```

Using bun:
```bash
bun run dev
```

The server will start on the configured port (default: 3000).

### 4. Expose to Internet (for MentraOS)

Use ngrok or similar to expose your local server:

```bash
ngrok http --url=<YOUR_NGROK_STATIC_URL> 3000
```

Update your app's webhook URL in the MentraOS Console to point to your ngrok URL.

## API Endpoints

### PhoneGPT iOS App Endpoints

- `GET /health` - Health check
- `GET /events?since=0&limit=100` - Poll for new events (voice input, app state changes)
- `POST /display` - Display text on glasses
  ```json
  {
    "text": "Hello from PhoneGPT!",
    "session_id": "optional-session-id",
    "duration": 5000
  }
  ```
- `GET /sessions` - Get all active sessions
- `GET /sessions/:sessionId` - Get session details
- `GET /stats` - Get server statistics
- `DELETE /events` - Clear event queue

### Web Dashboard

- `GET /dashboard` - Interactive web UI for monitoring and testing

## How It Works

### MentraOS Integration

1. User activates PhoneGPT app in MentraOS phone app
2. MentraOS sends webhook to your server
3. Server establishes session with glasses
4. Real-time voice transcription flows from glasses → server
5. Server can display text on glasses via SDK

### PhoneGPT iOS App Integration

1. iOS app polls `/events` endpoint every few seconds
2. When voice input detected, event appears in queue
3. iOS app processes with AI
4. iOS app sends response to `/display` endpoint
5. Server displays on glasses

## Event Types

Events available from `/events` endpoint:

- `app_activated` - User opened PhoneGPT in MentraOS
- `app_deactivated` - User closed PhoneGPT
- `voice_input` - Final voice transcription from glasses
  ```json
  {
    "type": "voice_input",
    "data": {
      "transcript": "What's the weather?",
      "session_id": "...",
      "is_final": true
    },
    "timestamp": "2025-11-04T02:00:00.000Z"
  }
  ```
- `display_request` - Text was displayed on glasses
- `battery_update` - Glasses battery status changed

## Project Structure

```
backend/
├── src/
│   └── index.ts          # Main server file
├── package.json          # Dependencies
├── tsconfig.json         # TypeScript config
├── .env.example          # Environment template
└── README_TYPESCRIPT.md  # This file
```

## Development

### Build for Production

```bash
npm run build
```

This creates compiled JavaScript in `dist/` directory.

### Run Production Build

```bash
npm start
```

## Deployment

1. Build the project: `npm run build`
2. Upload `dist/`, `package.json`, and `.env` to your server
3. Install production dependencies: `npm install --production`
4. Run: `node dist/index.js`
5. Use a process manager like PM2 for production:
   ```bash
   pm2 start dist/index.js --name phonegpt-mentraos
   ```

## Troubleshooting

### Server won't start

- Check that `PACKAGE_NAME` and `MENTRAOS_API_KEY` are set in `.env`
- Verify port is not already in use
- Check Node.js version (must be v18+)

### MentraOS can't connect

- Verify your webhook URL in MentraOS Console matches your ngrok URL
- Check that port matches between ngrok and server
- Look for webhook errors in server logs

### No events appearing

- Check that glasses are connected to MentraOS app
- Verify PhoneGPT app is activated in MentraOS
- Check `/stats` endpoint to see if sessions are active

## Links

- [MentraOS Console](https://console.mentra.glass)
- [MentraOS SDK Docs](https://docs.mentra.glass)
- [Example App](https://github.com/Mentra-Community/MentraOS-Cloud-Example-App)
