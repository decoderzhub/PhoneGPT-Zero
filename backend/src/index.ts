import { AppServer, AppSession, ViewType } from '@mentra/sdk';
import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const PACKAGE_NAME = process.env.PACKAGE_NAME ?? (() => { throw new Error('PACKAGE_NAME is not set in .env file'); })();
const MENTRAOS_API_KEY = process.env.MENTRAOS_API_KEY ?? (() => { throw new Error('MENTRAOS_API_KEY is not set in .env file'); })();
const PORT = parseInt(process.env.PORT || '3000');

interface SessionState {
  sessionId: string;
  userId: string;
  session: AppSession;
  state: 'listening' | 'processing' | 'displaying';
  currentTranscript: string;
  lastResponse: string;
  eventHistory: Array<{
    type: string;
    data: any;
    timestamp: string;
  }>;
}

interface QueuedEvent {
  type: string;
  data: any;
  timestamp: string;
  sessionId?: string;
}

class PhoneGPTMentraOSApp extends AppServer {
  private sessions: Map<string, SessionState> = new Map();
  private eventQueue: QueuedEvent[] = [];
  private readonly MAX_QUEUE_SIZE = 1000;

  private expressApp: express.Application;

  constructor() {
    super({
      packageName: PACKAGE_NAME,
      apiKey: MENTRAOS_API_KEY,
      port: PORT,
    });

    this.expressApp = express();
    this.setupExpress();
  }

  private setupExpress() {
    this.expressApp.use(cors());
    this.expressApp.use(express.json());

    this.expressApp.get('/health', this.handleHealthCheck.bind(this));
    this.expressApp.get('/events', this.handleGetEvents.bind(this));
    this.expressApp.post('/display', this.handleDisplayText.bind(this));
    this.expressApp.get('/sessions', this.handleGetSessions.bind(this));
    this.expressApp.get('/sessions/:sessionId', this.handleGetSessionDetails.bind(this));
    this.expressApp.get('/stats', this.handleGetStats.bind(this));
    this.expressApp.delete('/events', this.handleClearEvents.bind(this));
    this.expressApp.get('/dashboard', this.handleDashboard.bind(this));
  }

  private addEvent(eventType: string, data: any, sessionId?: string) {
    const event: QueuedEvent = {
      type: eventType,
      data,
      timestamp: new Date().toISOString(),
      sessionId,
    };

    this.eventQueue.push(event);

    if (this.eventQueue.length > this.MAX_QUEUE_SIZE) {
      this.eventQueue.shift();
    }

    if (sessionId) {
      const sessionState = this.sessions.get(sessionId);
      if (sessionState) {
        sessionState.eventHistory.push(event);
        if (sessionState.eventHistory.length > 100) {
          sessionState.eventHistory.shift();
        }
      }
    }

    console.log(`📨 Event: ${eventType}`, sessionId ? `(session: ${sessionId.substring(0, 12)}...)` : '');
  }

  protected async onSession(session: AppSession, sessionId: string, userId: string): Promise<void> {
    console.log('\n' + '='.repeat(50));
    console.log('🔵 NEW SESSION STARTED');
    console.log(`   Session ID: ${sessionId}`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Timestamp: ${new Date().toISOString()}`);
    console.log('='.repeat(50) + '\n');

    const sessionState: SessionState = {
      sessionId,
      userId,
      session,
      state: 'listening',
      currentTranscript: '',
      lastResponse: '',
      eventHistory: [],
    };

    this.sessions.set(sessionId, sessionState);

    this.addEvent('app_activated', {
      sessionId,
      userId,
    }, sessionId);

    session.layouts.showTextWall('✨ PhoneGPT Connected\n\nReady for voice commands!', {
      view: ViewType.MAIN,
      durationMs: 3000,
    });

    session.events.onTranscription((data) => {
      if (data.text) {
        sessionState.currentTranscript += ' ' + data.text;
      }

      if (data.isFinal) {
        const transcript = sessionState.currentTranscript.trim();

        console.log('\n' + '='.repeat(50));
        console.log('🎤 VOICE INPUT RECEIVED');
        console.log(`   Session: ${sessionId.substring(0, 20)}...`);
        console.log(`   Transcript: "${transcript}"`);
        console.log(`   Timestamp: ${new Date().toISOString()}`);
        console.log('='.repeat(50) + '\n');

        this.addEvent('voice_input', {
          transcript,
          sessionId,
          is_final: data.isFinal,
        }, sessionId);

        sessionState.state = 'processing';
        session.layouts.showTextWall(`🤔 Processing:\n"${transcript.substring(0, 50)}..."`, {
          view: ViewType.MAIN,
          durationMs: 2000,
        });

        sessionState.currentTranscript = '';
        sessionState.state = 'listening';
      }
    });

    session.events.onGlassesBattery((data) => {
      console.log('🔋 Glasses battery:', data);
      this.addEvent('battery_update', data, sessionId);
    });

    session.events.onSessionEnd(() => {
      console.log('\n' + '='.repeat(50));
      console.log('🔴 SESSION ENDED');
      console.log(`   Session ID: ${sessionId}`);
      console.log(`   Timestamp: ${new Date().toISOString()}`);
      console.log('='.repeat(50) + '\n');

      this.addEvent('app_deactivated', { sessionId }, sessionId);
      this.sessions.delete(sessionId);
    });
  }

  private handleHealthCheck(req: Request, res: Response) {
    console.log('📊 Health check requested');
    res.json({
      status: 'healthy',
      events_count: this.eventQueue.length,
      active_sessions: this.sessions.size,
      timestamp: new Date().toISOString(),
    });
  }

  private handleGetEvents(req: Request, res: Response) {
    const since = parseInt(req.query.since as string) || 0;
    const limit = parseInt(req.query.limit as string) || 100;

    const newEvents = this.eventQueue.slice(since, since + limit);

    if (newEvents.length > 0) {
      console.log(`📤 EVENTS POLLED: Returning ${newEvents.length} new events (since index ${since})`);
    }

    res.json({
      events: newEvents,
      count: this.eventQueue.length,
      last_index: Math.min(since + newEvents.length, this.eventQueue.length),
    });
  }

  private async handleDisplayText(req: Request, res: Response) {
    const { text, session_id, duration } = req.body;
    const durationMs = duration || 5000;

    console.log('\n' + '='.repeat(50));
    console.log('💬 DISPLAY REQUEST FROM PHONEGPT');
    console.log(`   Text: "${text}"`);
    console.log(`   Session: ${session_id || 'all'}`);
    console.log(`   Duration: ${durationMs}ms`);
    console.log('='.repeat(50) + '\n');

    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }

    const displayed: string[] = [];

    if (session_id) {
      const sessionState = this.sessions.get(session_id);
      if (sessionState) {
        sessionState.session.layouts.showTextWall(text, {
          view: ViewType.MAIN,
          durationMs,
        });
        sessionState.lastResponse = text;
        sessionState.state = 'displaying';
        displayed.push(session_id);
        console.log(`💬 DISPLAYED ON GLASSES: "${text}"`);
      }
    } else {
      for (const [sid, sessionState] of this.sessions.entries()) {
        sessionState.session.layouts.showTextWall(text, {
          view: ViewType.MAIN,
          durationMs,
        });
        sessionState.lastResponse = text;
        sessionState.state = 'displaying';
        displayed.push(sid);
      }
      console.log(`💬 DISPLAYED ON ${displayed.length} GLASSES`);
    }

    if (displayed.length === 0) {
      console.log('❌ No active sessions to display on\n');
      return res.status(404).json({ error: 'No active sessions' });
    }

    console.log(`✅ Displayed on ${displayed.length} session(s)\n`);

    this.addEvent('display_request', {
      text,
      sessions: displayed,
      duration: durationMs,
    });

    res.json({
      status: 'displayed',
      sessions: displayed,
      text,
      timestamp: new Date().toISOString(),
    });
  }

  private handleGetSessions(req: Request, res: Response) {
    console.log(`📊 Active sessions requested: ${this.sessions.size} active`);

    const sessions = Array.from(this.sessions.values()).map((state) => ({
      session_id: state.sessionId,
      state: state.state,
      user_id: state.userId,
      last_transcript: state.currentTranscript,
      last_response: state.lastResponse,
      event_count: state.eventHistory.length,
    }));

    res.json({
      sessions,
      count: sessions.length,
      timestamp: new Date().toISOString(),
    });
  }

  private handleGetSessionDetails(req: Request, res: Response) {
    const sessionId = req.params.sessionId;
    const sessionState = this.sessions.get(sessionId);

    if (!sessionState) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.json({
      session_id: sessionState.sessionId,
      state: sessionState.state,
      user_id: sessionState.userId,
      current_transcript: sessionState.currentTranscript,
      last_response: sessionState.lastResponse,
      event_history: sessionState.eventHistory.slice(-10),
      timestamp: new Date().toISOString(),
    });
  }

  private handleGetStats(req: Request, res: Response) {
    const eventTypes: Record<string, number> = {};
    for (const event of this.eventQueue) {
      eventTypes[event.type] = (eventTypes[event.type] || 0) + 1;
    }

    console.log('📊 Stats requested:', eventTypes);

    res.json({
      total_events: this.eventQueue.length,
      event_types: eventTypes,
      active_sessions: this.sessions.size,
      queue_capacity: this.MAX_QUEUE_SIZE,
      timestamp: new Date().toISOString(),
    });
  }

  private handleClearEvents(req: Request, res: Response) {
    this.eventQueue = [];
    console.log('🗑️  Event queue cleared');
    res.json({ status: 'cleared', timestamp: new Date().toISOString() });
  }

  private handleDashboard(req: Request, res: Response) {
    res.send(`
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
            .container { max-width: 1200px; margin: 0 auto; }
            h1 { color: white; text-align: center; margin-bottom: 30px; }
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
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🥽 PhoneGPT MentraOS Bridge</h1>
            <div class="card">
                <h2>📊 Status</h2>
                <p>Status: <span class="status active">Running</span></p>
                <p>Sessions: <span id="session-count">0</span></p>
                <p>Events: <span id="event-count">0</span></p>
                <button onclick="refreshStats()">Refresh</button>
            </div>
            <div class="card">
                <h2>👥 Sessions</h2>
                <div id="sessions"></div>
            </div>
            <div class="card">
                <h2>📨 Events</h2>
                <div id="events"></div>
            </div>
            <div class="card">
                <h2>🧪 Test</h2>
                <input type="text" id="test-text" placeholder="Text..." style="width: 70%; padding: 8px;">
                <button onclick="testDisplay()">Send</button>
            </div>
        </div>
        <script>
            async function refreshStats() {
                const stats = await fetch('/stats').then(r => r.json());
                document.getElementById('session-count').textContent = stats.active_sessions;
                document.getElementById('event-count').textContent = stats.total_events;

                const sessions = await fetch('/sessions').then(r => r.json());
                document.getElementById('sessions').innerHTML = sessions.sessions.map(s => \`
                    <div class="event-item">
                        <strong>ID:</strong> \${s.session_id.substring(0, 20)}...<br>
                        <strong>State:</strong> \${s.state}<br>
                        <strong>User:</strong> \${s.user_id}
                    </div>
                \`).join('') || '<p>No sessions</p>';

                const events = await fetch('/events?limit=10').then(r => r.json());
                document.getElementById('events').innerHTML = events.events.slice(-10).reverse().map(e => \`
                    <div class="event-item">
                        <strong>\${e.type}</strong> - \${new Date(e.timestamp).toLocaleTimeString()}
                    </div>
                \`).join('') || '<p>No events</p>';
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
            }

            refreshStats();
            setInterval(refreshStats, 3000);
        </script>
    </body>
    </html>
    `);
  }

  public async start() {
    await super.start();
    console.log('\n' + '='.repeat(50));
    console.log('🚀 PHONEGPT MENTRAOS SERVER STARTED');
    console.log('='.repeat(50));
    console.log(`   Package: ${PACKAGE_NAME}`);
    console.log(`   Port: ${PORT}`);
    console.log(`   Endpoints:`);
    console.log(`   - GET /health`);
    console.log(`   - GET /events (PhoneGPT polling)`);
    console.log(`   - POST /display (PhoneGPT display)`);
    console.log(`   - GET /dashboard (Web UI)`);
    console.log(`   - MentraOS webhooks (handled by SDK)`);
    console.log(`   Timestamp: ${new Date().toISOString()}`);
    console.log('='.repeat(50) + '\n');
  }
}

const app = new PhoneGPTMentraOSApp();

app.start().catch(console.error);
