"""
PhoneGPT MentraOS Webhook Server
Handles communication between MentraOS glasses and PhoneGPT iOS app
"""

from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
import logging
import asyncio
from collections import deque
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="PhoneGPT MentraOS Bridge",
    description="Webhook server bridging MentraOS glasses and PhoneGPT AI",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class WebhookEvent(BaseModel):
    type: str = Field(..., description="Event type from MentraOS")
    data: Dict[str, Any] = Field(default_factory=dict, description="Event data")
    timestamp: Optional[str] = Field(default_factory=lambda: datetime.utcnow().isoformat())
    device_id: Optional[str] = Field(None, description="Device identifier")

class DisplayRequest(BaseModel):
    text: str = Field(..., description="Text to display on glasses")
    device_id: Optional[str] = Field(None, description="Target device")
    duration: Optional[int] = Field(5, description="Display duration in seconds")

class EventsResponse(BaseModel):
    events: List[WebhookEvent]
    count: int
    last_index: int

event_queue = deque(maxlen=1000)
active_sessions: Dict[str, Dict[str, Any]] = {}

@app.get("/")
async def root():
    """Health check and info endpoint"""
    return {
        "service": "PhoneGPT MentraOS Bridge",
        "status": "healthy",
        "events_queued": len(event_queue),
        "active_sessions": len(active_sessions),
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "events_count": len(event_queue),
        "active_sessions": len(active_sessions),
        "uptime": "running",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/webhook")
async def mentraos_webhook(event: WebhookEvent, background_tasks: BackgroundTasks):
    """
    Main webhook endpoint that MentraOS calls

    Event types:
    - app_activated: User opened PhoneGPT in MentraOS
    - voice_input: User spoke (includes transcript)
    - gesture: User made gesture (tap, swipe, etc)
    - app_deactivated: User closed PhoneGPT
    - connection_status: Device connection changed
    """
    print("\n" + "="*50)
    print(f"📨 WEBHOOK RECEIVED")
    print(f"   Type: {event.type}")
    print(f"   Device: {event.device_id}")
    print(f"   Data: {event.data}")
    print(f"   Timestamp: {datetime.utcnow().isoformat()}")
    print("="*50 + "\n")

    logger.info(f"Received webhook: type={event.type}, device={event.device_id}, data={event.data}")

    event_queue.append(event)

    if event.type == "session_request":
        print(f"🔌 SESSION REQUEST")
        print(f"   This is MentraOS trying to connect!")
        print(f"   Data: {event.data}\n")
        logger.info(f"Session request received: {event.data}")

    elif event.type == "app_activated":
        device_id = event.device_id or "default"
        active_sessions[device_id] = {
            "activated_at": datetime.utcnow().isoformat(),
            "last_activity": datetime.utcnow().isoformat(),
            "status": "active"
        }
        print(f"🔵 NEW SESSION STARTED")
        print(f"   Device ID: {device_id}")
        print(f"   Active sessions: {len(active_sessions)}\n")
        logger.info(f"Session activated for device: {device_id}")

    elif event.type == "app_deactivated":
        device_id = event.device_id or "default"
        if device_id in active_sessions:
            del active_sessions[device_id]
        print(f"🔴 SESSION ENDED")
        print(f"   Device ID: {device_id}")
        print(f"   Active sessions: {len(active_sessions)}\n")
        logger.info(f"Session deactivated for device: {device_id}")

    elif event.type == "voice_input":
        transcript = event.data.get("transcript", "")
        print(f"🎤 VOICE INPUT RECEIVED")
        print(f"   Transcript: \"{transcript}\"")
        print(f"   Device: {event.device_id}\n")
        logger.info(f"Voice input received: '{transcript}'")

    elif event.type == "gesture":
        gesture_type = event.data.get("gesture_type", "unknown")
        print(f"👆 GESTURE DETECTED")
        print(f"   Type: {gesture_type}")
        print(f"   Device: {event.device_id}\n")
        logger.info(f"Gesture received: {gesture_type}")

    else:
        print(f"❓ UNKNOWN EVENT TYPE: {event.type}")
        print(f"   Data: {event.data}")
        print(f"   Device: {event.device_id}\n")
        logger.warning(f"Unknown event type: {event.type}, data: {event.data}")

    return JSONResponse({
        "status": "received",
        "event_id": len(event_queue),
        "timestamp": datetime.utcnow().isoformat()
    })

@app.get("/events")
async def get_events(since: int = 0, limit: int = 100):
    """
    Poll for new events - PhoneGPT app calls this

    Parameters:
    - since: Last event index received
    - limit: Max events to return
    """
    events_list = list(event_queue)
    new_events = events_list[since:since + limit]

    if new_events:
        print(f"📤 EVENTS POLLED: Returning {len(new_events)} new events (since index {since})")

    return EventsResponse(
        events=new_events,
        count=len(events_list),
        last_index=min(since + len(new_events), len(events_list))
    )

@app.post("/display")
async def request_display(request: DisplayRequest):
    """
    PhoneGPT can call this to queue a display request
    (Future: Could forward to MentraOS API if available)
    """
    logger.info(f"Display request: '{request.text}' (device: {request.device_id})")

    event = WebhookEvent(
        type="display_request",
        data={
            "text": request.text,
            "duration": request.duration
        },
        device_id=request.device_id
    )
    event_queue.append(event)

    return {
        "status": "queued",
        "text": request.text,
        "device_id": request.device_id,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/sessions")
async def get_active_sessions():
    """Get all active device sessions"""
    return {
        "sessions": active_sessions,
        "count": len(active_sessions),
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/sessions/{device_id}/heartbeat")
async def session_heartbeat(device_id: str):
    """Update session last activity timestamp"""
    if device_id in active_sessions:
        active_sessions[device_id]["last_activity"] = datetime.utcnow().isoformat()
        return {"status": "updated", "device_id": device_id}
    else:
        raise HTTPException(status_code=404, detail="Session not found")

@app.delete("/events")
async def clear_events():
    """Clear event queue (admin endpoint)"""
    event_queue.clear()
    return {"status": "cleared", "timestamp": datetime.utcnow().isoformat()}

@app.get("/stats")
async def get_stats():
    """Get server statistics"""
    event_types = {}
    for event in event_queue:
        event_types[event.type] = event_types.get(event.type, 0) + 1

    return {
        "total_events": len(event_queue),
        "event_types": event_types,
        "active_sessions": len(active_sessions),
        "queue_capacity": event_queue.maxlen,
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn

    print("\n" + "="*50)
    print("🚀 STARTING PHONEGPT MENTRAOS SERVER")
    print("="*50)
    print(f"   Port: 8000")
    print(f"   Endpoints:")
    print(f"   - POST /webhook (MentraOS posts here)")
    print(f"   - GET /events (PhoneGPT polls here)")
    print(f"   - GET /health")
    print(f"   Timestamp: {datetime.utcnow().isoformat()}")
    print("="*50 + "\n")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
