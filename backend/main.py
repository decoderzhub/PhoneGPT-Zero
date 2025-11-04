"""
PhoneGPT Integration for MentraOS Smart Glasses
Bridges PhoneGPT AI with Even Realities glasses via MentraOS SDK
"""

import os
import asyncio
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from enum import Enum
import sys

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

from mentraos_sdk.fastapi_integration import MentraOSApp
from mentraos_sdk.layouts import TextWall, DoubleTextWall
from mentraos_sdk.types import TranscriptionData

from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Configuration
PACKAGE_NAME = os.getenv("MENTRAOS_PACKAGE_NAME", "com.codeofhonor.phonegpt")
MENTRA_API_KEY = os.getenv("MENTRAOS_API_KEY", "")
WEBHOOK_SECRET = os.getenv("MENTRAOS_WEBHOOK_SECRET", "")
PORT = int(os.getenv("PORT", "8000"))

if not MENTRA_API_KEY:
    logger.warning("⚠️  MENTRAOS_API_KEY not set - get it from https://console.mentra.glass")

# Initialize MentraOS app
mentra_app = MentraOSApp(
    package_name=PACKAGE_NAME,
    api_key=MENTRA_API_KEY,
    webhook_secret=WEBHOOK_SECRET if WEBHOOK_SECRET else None
)

# Create FastAPI app with MentraOS integration
app = mentra_app.create_fastapi_app()

# Add CORS for PhoneGPT iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ===== State Management =====

class GlassesState(Enum):
    LISTENING = "listening"
    PROCESSING = "processing"
    DISPLAYING = "displaying"


class SessionData(BaseModel):
    state: GlassesState = GlassesState.LISTENING
    current_transcript: str = ""
    last_response: str = ""
    event_history: List[Dict[str, Any]] = []


# Store session states
session_states: Dict[str, SessionData] = {}

# Event queue for PhoneGPT iOS app polling
from collections import deque
event_queue = deque(maxlen=1000)


# ===== Helper Functions =====

def add_event(event_type: str, data: Dict[str, Any], session_id: Optional[str] = None):
    """Add event to queue for iOS app"""
    event = {
        "type": event_type,
        "data": data,
        "timestamp": datetime.utcnow().isoformat(),
        "session_id": session_id
    }
    event_queue.append(event)

    if session_id and session_id in session_states:
        session_states[session_id].event_history.append(event)


async def display_on_glasses(session_id: str, text: str, duration_ms: int = 3000):
    """Display text on glasses"""
    try:
        session = mentra_app._get_session(session_id)
        await session.display.show(
            TextWall(
                text=text,
                font_size="medium",
                alignment="center"
            ),
            duration_ms=duration_ms
        )
        print(f"💬 DISPLAYED ON GLASSES: \"{text}\"")
    except Exception as e:
        logger.error(f"Display error: {e}")


# ===== Session Event Handlers =====

@mentra_app.on_session_start
async def handle_session_start(session_id: str, user_id: str):
    """Handle new MentraOS session"""
    print("\n" + "="*50)
    print("🔵 NEW SESSION STARTED")
    print(f"   Session ID: {session_id}")
    print(f"   User ID: {user_id}")
    print(f"   Timestamp: {datetime.utcnow().isoformat()}")
    print("="*50 + "\n")

    # Initialize session state
    session_states[session_id] = SessionData()

    # Add event for iOS app
    add_event("app_activated", {
        "session_id": session_id,
        "user_id": user_id
    }, session_id)

    # Display welcome message
    await display_on_glasses(
        session_id,
        "✨ PhoneGPT Connected\n\nReady for voice commands!",
        duration_ms=3000
    )

    # Set up transcription handler
    session = mentra_app._get_session(session_id)

    @session.audio.on_transcription
    async def on_transcription(data: TranscriptionData):
        await handle_transcription(session_id, data)

    print(f"✅ Session {session_id} configured and ready\n")


@mentra_app.on_session_end
async def handle_session_end(session_id: str):
    """Handle session disconnect"""
    print("\n" + "="*50)
    print("🔴 SESSION ENDED")
    print(f"   Session ID: {session_id}")
    print(f"   Timestamp: {datetime.utcnow().isoformat()}")
    print("="*50 + "\n")

    # Add event for iOS app
    add_event("app_deactivated", {"session_id": session_id}, session_id)

    # Clean up state
    if session_id in session_states:
        del session_states[session_id]


async def handle_transcription(session_id: str, transcription: TranscriptionData):
    """Handle voice transcription from glasses"""
    state = session_states.get(session_id)
    if not state:
        return

    # Add to transcript buffer
    state.current_transcript += " " + transcription.text

    # Only process final transcriptions
    if not transcription.is_final:
        return

    transcript_text = state.current_transcript.strip()

    print("\n" + "="*50)
    print("🎤 VOICE INPUT RECEIVED")
    print(f"   Session: {session_id}")
    print(f"   Transcript: \"{transcript_text}\"")
    print(f"   Is Final: {transcription.is_final}")
    print(f"   Timestamp: {datetime.utcnow().isoformat()}")
    print("="*50 + "\n")

    # Add event for iOS app
    add_event("voice_input", {
        "transcript": transcript_text,
        "session_id": session_id,
        "is_final": transcription.is_final
    }, session_id)

    # Show processing message
    state.state = GlassesState.PROCESSING
    await display_on_glasses(
        session_id,
        f"🤔 Processing:\n\"{transcript_text[:50]}...\"",
        duration_ms=2000
    )

    # Reset transcript for next input
    state.current_transcript = ""
    state.state = GlassesState.LISTENING


# ===== PhoneGPT Integration Routes =====

@app.get("/")
async def root():
    """Health check and info endpoint"""
    print("📊 Root endpoint accessed")
    return {
        "service": "PhoneGPT MentraOS Bridge",
        "status": "healthy",
        "events_queued": len(event_queue),
        "active_sessions": len(session_states),
        "package_name": PACKAGE_NAME,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    print("📊 Health check requested")
    return {
        "status": "healthy",
        "events_count": len(event_queue),
        "active_sessions": len(session_states),
        "sdk_initialized": mentra_app is not None,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/events")
async def get_events(since: int = 0, limit: int = 100):
    """
    Poll for new events - PhoneGPT iOS app calls this

    Parameters:
    - since: Last event index received
    - limit: Max events to return
    """
    events_list = list(event_queue)
    new_events = events_list[since:since + limit]

    if new_events:
        print(f"📤 EVENTS POLLED: Returning {len(new_events)} new events (since index {since})")

    return {
        "events": new_events,
        "count": len(events_list),
        "last_index": min(since + len(new_events), len(events_list))
    }


@app.post("/display")
async def display_text(request: Dict[str, Any]):
    """
    Display text on glasses - PhoneGPT iOS app calls this

    Request body:
    - text: Text to display
    - session_id: Optional target session
    - duration: Display duration in milliseconds (default: 5000)
    """
    text = request.get("text", "")
    session_id = request.get("session_id")
    duration = request.get("duration", 5000)

    print("\n" + "="*50)
    print("💬 DISPLAY REQUEST FROM PHONEGPT")
    print(f"   Text: \"{text}\"")
    print(f"   Session: {session_id or 'all'}")
    print(f"   Duration: {duration}ms")
    print("="*50 + "\n")

    if not text:
        raise HTTPException(status_code=400, detail="Text is required")

    displayed = []

    if session_id and session_id in session_states:
        # Display on specific session
        await display_on_glasses(session_id, text, duration)
        displayed.append(session_id)

        # Update state
        state = session_states[session_id]
        state.last_response = text
        state.state = GlassesState.DISPLAYING

    elif not session_id and session_states:
        # Display on all active sessions
        for sid in list(session_states.keys()):
            await display_on_glasses(sid, text, duration)
            displayed.append(sid)

            # Update state
            state = session_states[sid]
            state.last_response = text
            state.state = GlassesState.DISPLAYING

    if not displayed:
        print("❌ No active sessions to display on\n")
        raise HTTPException(status_code=404, detail="No active sessions")

    print(f"✅ Displayed on {len(displayed)} session(s)\n")

    # Add event
    add_event("display_request", {
        "text": text,
        "sessions": displayed,
        "duration": duration
    })

    return {
        "status": "displayed",
        "sessions": displayed,
        "text": text,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/sessions")
async def get_active_sessions():
    """Get all active sessions"""
    print(f"📊 Active sessions requested: {len(session_states)} active")

    sessions = []
    for session_id, state in session_states.items():
        sessions.append({
            "session_id": session_id,
            "state": state.state.value,
            "last_transcript": state.current_transcript,
            "last_response": state.last_response,
            "event_count": len(state.event_history)
        })

    return {
        "sessions": sessions,
        "count": len(sessions),
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/sessions/{session_id}")
async def get_session_details(session_id: str):
    """Get details for a specific session"""
    if session_id not in session_states:
        raise HTTPException(status_code=404, detail="Session not found")

    state = session_states[session_id]
    return {
        "session_id": session_id,
        "state": state.state.value,
        "current_transcript": state.current_transcript,
        "last_response": state.last_response,
        "event_history": state.event_history[-10:],  # Last 10 events
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/stats")
async def get_stats():
    """Get server statistics"""
    event_types = {}
    for event in event_queue:
        event_type = event.get("type", "unknown")
        event_types[event_type] = event_types.get(event_type, 0) + 1

    print(f"📊 Stats requested: {event_types}")

    return {
        "total_events": len(event_queue),
        "event_types": event_types,
        "active_sessions": len(session_states),
        "queue_capacity": event_queue.maxlen,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.delete("/events")
async def clear_events():
    """Clear event queue (admin endpoint)"""
    event_queue.clear()
    print("🗑️  Event queue cleared")
    return {"status": "cleared", "timestamp": datetime.utcnow().isoformat()}


# ===== Web Dashboard =====

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard():
    """Web dashboard for monitoring"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>PhoneGPT MentraOS Bridge</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }
            .container {
                max-width: 1200px;
                margin: 0 auto;
            }
            h1 {
                color: white;
                text-align: center;
                margin-bottom: 30px;
            }
            .card {
                background: white;
                border-radius: 12px;
                padding: 25px;
                margin-bottom: 20px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            }
            .status {
                display: inline-block;
                padding: 6px 12px;
                border-radius: 20px;
                font-size: 14px;
                font-weight: 600;
            }
            .status.active { background: #48bb78; color: white; }
            .status.inactive { background: #e53e3e; color: white; }
            #events, #sessions {
                background: #f7fafc;
                border: 1px solid #e2e8f0;
                border-radius: 8px;
                padding: 15px;
                max-height: 300px;
                overflow-y: auto;
                font-family: 'Courier New', monospace;
                font-size: 12px;
            }
            .event-item {
                padding: 8px;
                margin: 5px 0;
                background: white;
                border-radius: 4px;
                border-left: 3px solid #667eea;
            }
            button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                padding: 10px 20px;
                margin: 5px;
                border-radius: 8px;
                cursor: pointer;
                font-size: 14px;
            }
            button:hover {
                opacity: 0.9;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🥽 PhoneGPT MentraOS Bridge</h1>

            <div class="card">
                <h2>📊 Server Status</h2>
                <p>Status: <span class="status active">Running</span></p>
                <p>Active Sessions: <span id="session-count">0</span></p>
                <p>Queued Events: <span id="event-count">0</span></p>
                <button onclick="refreshStats()">Refresh</button>
            </div>

            <div class="card">
                <h2>👥 Active Sessions</h2>
                <div id="sessions"></div>
            </div>

            <div class="card">
                <h2>📨 Recent Events</h2>
                <div id="events"></div>
                <button onclick="clearEvents()">Clear Events</button>
            </div>

            <div class="card">
                <h2>🧪 Test Display</h2>
                <input type="text" id="test-text" placeholder="Enter text to display..." style="width: 70%; padding: 8px;">
                <button onclick="testDisplay()">Send to Glasses</button>
            </div>
        </div>

        <script>
            async function refreshStats() {
                const stats = await fetch('/stats').then(r => r.json());
                document.getElementById('session-count').textContent = stats.active_sessions;
                document.getElementById('event-count').textContent = stats.total_events;

                const sessions = await fetch('/sessions').then(r => r.json());
                const sessionsDiv = document.getElementById('sessions');
                sessionsDiv.innerHTML = sessions.sessions.map(s => `
                    <div class="event-item">
                        <strong>Session:</strong> ${s.session_id.substring(0, 12)}...<br>
                        <strong>State:</strong> ${s.state}<br>
                        <strong>Events:</strong> ${s.event_count}
                    </div>
                `).join('') || '<p>No active sessions</p>';

                const events = await fetch('/events?since=0&limit=20').then(r => r.json());
                const eventsDiv = document.getElementById('events');
                eventsDiv.innerHTML = events.events.slice(-10).reverse().map(e => `
                    <div class="event-item">
                        <strong>${e.type}</strong> - ${new Date(e.timestamp).toLocaleTimeString()}<br>
                        ${JSON.stringify(e.data).substring(0, 100)}
                    </div>
                `).join('') || '<p>No events</p>';
            }

            async function clearEvents() {
                await fetch('/events', { method: 'DELETE' });
                refreshStats();
            }

            async function testDisplay() {
                const text = document.getElementById('test-text').value;
                if (!text) return;

                await fetch('/display', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ text })
                });

                document.getElementById('test-text').value = '';
                alert('Sent to glasses!');
            }

            refreshStats();
            setInterval(refreshStats, 3000);
        </script>
    </body>
    </html>
    """


# ===== Main =====

def main():
    """Run the application"""
    print("\n" + "="*50)
    print("🚀 STARTING PHONEGPT MENTRAOS SERVER")
    print("="*50)
    print(f"   Package: {PACKAGE_NAME}")
    print(f"   Port: {PORT}")
    print(f"   Endpoints:")
    print(f"   - GET / (health)")
    print(f"   - GET /events (PhoneGPT polling)")
    print(f"   - POST /display (PhoneGPT display)")
    print(f"   - GET /dashboard (web UI)")
    print(f"   - MentraOS webhooks (handled by SDK)")
    print(f"   Timestamp: {datetime.utcnow().isoformat()}")
    print("="*50 + "\n")

    if not MENTRA_API_KEY:
        print("⚠️  WARNING: MENTRAOS_API_KEY not set!")
        print("   Get your API key from: https://console.mentra.glass")
        print("   Set it in .env file\n")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=PORT,
        log_level="info"
    )


if __name__ == "__main__":
    main()
