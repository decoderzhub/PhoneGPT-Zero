import { AppServer, AppSession } from "@mentra/sdk"
import express, { Request, Response } from "express"
import cors from "cors"
import * as dotenv from "dotenv"

dotenv.config()

const PACKAGE_NAME = process.env.PACKAGE_NAME || "com.codeofhonor.phonegpt"
const PORT = parseInt(process.env.PORT || "3000")
const MENTRAOS_API_KEY = process.env.MENTRAOS_API_KEY
const API_PORT = parseInt(process.env.API_PORT || "3001")

if (!MENTRAOS_API_KEY) {
  console.error("❌ MENTRAOS_API_KEY environment variable is required")
  console.error("   Get your API key from: https://console.mentra.glass")
  process.exit(1)
}

interface EventData {
  type: string
  data: any
  timestamp: string
  sessionId?: string
  userId?: string
}

const eventQueue: EventData[] = []
const activeSessions = new Map<string, AppSession>()

/**
 * PhoneGPT MentraOS Integration Server
 * Handles sessions from MentraOS and bridges with PhoneGPT iOS app
 */
class PhoneGPTApp extends AppServer {
  /**
   * Handle new session connections from MentraOS
   */
  protected async onSession(session: AppSession, sessionId: string, userId: string): Promise<void> {
    console.log(`\n🔵 ================================`)
    console.log(`📱 NEW SESSION STARTED`)
    console.log(`   Session ID: ${sessionId}`)
    console.log(`   User ID: ${userId}`)
    console.log(`   Timestamp: ${new Date().toISOString()}`)
    console.log(`================================\n`)

    session.logger.info(`New session: ${sessionId} for user ${userId}`)

    activeSessions.set(sessionId, session)

    eventQueue.push({
      type: "app_activated",
      data: { sessionId, userId },
      timestamp: new Date().toISOString(),
      sessionId,
      userId
    })

    session.layouts.showTextWall("✨ PhoneGPT AI Connected\n\nReady for voice commands!")
    console.log(`💬 Displayed welcome message on glasses`)

    session.events.onVoiceTranscript((transcript) => {
      console.log(`\n🎤 ================================`)
      console.log(`VOICE INPUT RECEIVED`)
      console.log(`   Session: ${sessionId}`)
      console.log(`   User: ${userId}`)
      console.log(`   Transcript: "${transcript}"`)
      console.log(`   Timestamp: ${new Date().toISOString()}`)
      console.log(`================================\n`)

      session.logger.info(`Voice input: "${transcript}"`)

      eventQueue.push({
        type: "voice_input",
        data: {
          transcript,
          sessionId,
          userId
        },
        timestamp: new Date().toISOString(),
        sessionId,
        userId
      })

      session.layouts.showTextWall(`🎤 Processing: "${transcript}"\n\nThinking...`)
      console.log(`💬 Showed processing message on glasses`)
    })

    session.events.onButton((button) => {
      console.log(`\n👆 ================================`)
      console.log(`BUTTON PRESSED`)
      console.log(`   Session: ${sessionId}`)
      console.log(`   Button: ${button}`)
      console.log(`   Timestamp: ${new Date().toISOString()}`)
      console.log(`================================\n`)

      session.logger.info(`Button pressed: ${button}`)

      eventQueue.push({
        type: "gesture",
        data: {
          gesture_type: button,
          sessionId,
          userId
        },
        timestamp: new Date().toISOString(),
        sessionId,
        userId
      })
    })

    session.events.onDisconnected(() => {
      console.log(`\n🔴 ================================`)
      console.log(`SESSION DISCONNECTED`)
      console.log(`   Session ID: ${sessionId}`)
      console.log(`   User ID: ${userId}`)
      console.log(`   Timestamp: ${new Date().toISOString()}`)
      console.log(`================================\n`)

      session.logger.info(`Session ${sessionId} disconnected`)

      activeSessions.delete(sessionId)

      eventQueue.push({
        type: "app_deactivated",
        data: { sessionId, userId },
        timestamp: new Date().toISOString(),
        sessionId,
        userId
      })
    })

    console.log(`✅ Session ${sessionId} fully configured and ready\n`)
  }
}

const mentraServer = new PhoneGPTApp({
  packageName: PACKAGE_NAME,
  apiKey: MENTRAOS_API_KEY,
  port: PORT,
})

const apiServer = express()
apiServer.use(cors())
apiServer.use(express.json())

apiServer.get("/", (req: Request, res: Response) => {
  res.json({
    service: "PhoneGPT MentraOS Bridge",
    status: "healthy",
    mentraos_port: PORT,
    api_port: API_PORT,
    events_queued: eventQueue.length,
    active_sessions: activeSessions.size,
    timestamp: new Date().toISOString()
  })
})

apiServer.get("/health", (req: Request, res: Response) => {
  console.log(`📊 Health check requested`)
  res.json({
    status: "healthy",
    events_count: eventQueue.length,
    active_sessions: activeSessions.size,
    timestamp: new Date().toISOString()
  })
})

apiServer.get("/events", (req: Request, res: Response) => {
  const since = parseInt(req.query.since as string) || 0
  const limit = parseInt(req.query.limit as string) || 100

  const newEvents = eventQueue.slice(since, since + limit)

  console.log(`📥 Events polled: since=${since}, returning ${newEvents.length} events`)

  res.json({
    events: newEvents,
    count: eventQueue.length,
    last_index: Math.min(since + newEvents.length, eventQueue.length)
  })
})

apiServer.post("/display", async (req: Request, res: Response) => {
  const { text, sessionId } = req.body

  console.log(`\n💬 ================================`)
  console.log(`DISPLAY REQUEST`)
  console.log(`   Text: "${text}"`)
  console.log(`   Session: ${sessionId || "all"}`)
  console.log(`   Timestamp: ${new Date().toISOString()}`)
  console.log(`================================\n`)

  if (sessionId && activeSessions.has(sessionId)) {
    const session = activeSessions.get(sessionId)!
    session.layouts.showTextWall(text)
    console.log(`✅ Displayed on session: ${sessionId}`)

    res.json({
      status: "displayed",
      sessionId,
      text
    })
  } else if (!sessionId && activeSessions.size > 0) {
    for (const [sid, session] of activeSessions.entries()) {
      session.layouts.showTextWall(text)
      console.log(`✅ Displayed on session: ${sid}`)
    }

    res.json({
      status: "displayed",
      sessions: activeSessions.size,
      text
    })
  } else {
    console.log(`❌ No active sessions found`)
    res.status(404).json({
      error: "No active sessions",
      sessionId: sessionId || null
    })
  }
})

apiServer.get("/sessions", (req: Request, res: Response) => {
  const sessions = Array.from(activeSessions.keys())

  console.log(`📊 Active sessions requested: ${sessions.length} active`)

  res.json({
    sessions: sessions.map(sessionId => ({ sessionId })),
    count: sessions.length,
    timestamp: new Date().toISOString()
  })
})

apiServer.get("/stats", (req: Request, res: Response) => {
  const eventTypes: Record<string, number> = {}

  for (const event of eventQueue) {
    eventTypes[event.type] = (eventTypes[event.type] || 0) + 1
  }

  console.log(`📊 Stats requested:`, eventTypes)

  res.json({
    total_events: eventQueue.length,
    event_types: eventTypes,
    active_sessions: activeSessions.size,
    timestamp: new Date().toISOString()
  })
})

async function start() {
  try {
    console.log(`\n🚀 ================================`)
    console.log(`STARTING PHONEGPT MENTRAOS SERVER`)
    console.log(`================================`)
    console.log(`Package Name: ${PACKAGE_NAME}`)
    console.log(`MentraOS Port: ${PORT}`)
    console.log(`API Port: ${API_PORT}`)
    console.log(`Timestamp: ${new Date().toISOString()}`)
    console.log(`================================\n`)

    await mentraServer.start()
    console.log(`✅ MentraOS server started on port ${PORT}`)

    apiServer.listen(API_PORT, () => {
      console.log(`✅ API server started on port ${API_PORT}`)
      console.log(`\n📡 Server is ready!`)
      console.log(`   MentraOS endpoint: http://localhost:${PORT}`)
      console.log(`   API endpoint: http://localhost:${API_PORT}`)
      console.log(`   Health check: http://localhost:${API_PORT}/health`)
      console.log(`   Events: http://localhost:${API_PORT}/events`)
      console.log(`\n⏳ Waiting for MentraOS connections...\n`)
    })
  } catch (err) {
    console.error("\n❌ ================================")
    console.error("FAILED TO START SERVER")
    console.error("================================")
    console.error("Error:", err)
    console.error("================================\n")
    process.exit(1)
  }
}

start()
