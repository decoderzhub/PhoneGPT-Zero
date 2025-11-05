const originalLog = console.log;
console.log = function(...args: any[]) {
  const msg = args.join(' ');
  if (msg.includes('[auth.middleware]')) return;
  originalLog.apply(console, args);
};

const originalStderr = process.stderr.write;
process.stderr.write = function(str: any, ...args: any[]) {
  if (str?.includes?.('[auth.middleware]')) return true;
  return originalStderr.apply(process.stderr, [str, ...args]);
};

import { AppServer, AppSession, ViewType } from '@mentra/sdk';
import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import axios from 'axios';
import Anthropic from '@anthropic-ai/sdk';
import Database from 'better-sqlite3';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import path from 'path';
import { PDFParse, TextResult } from 'pdf-parse'

dotenv.config();

const originalError = console.error;
console.error = function(...args: any[]) {
  const msg = args[0]?.toString?.() || '';
  if (msg.includes('Frontend token') || msg.includes('verifyFrontendToken')) return;
  originalError.apply(console, args);
};

// ============================================================================
// Environment Configuration
// ============================================================================
const PACKAGE_NAME = process.env.PACKAGE_NAME ?? (() => { throw new Error('PACKAGE_NAME is not set in .env file'); })();
const MENTRAOS_API_KEY = process.env.MENTRAOS_API_KEY ?? (() => { throw new Error('MENTRAOS_API_KEY is not set in .env file'); })();
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? (() => { throw new Error('ANTHROPIC_API_KEY is not set in .env file'); })();
const JWT_SECRET = process.env.JWT_SECRET || 'your-jwt-secret-key-change-in-production';
const PORT = parseInt(process.env.PORT || '8112');
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8112';
const LLM_MODEL = process.env.LLM_MODEL || 'claude-3-haiku-20240307';

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

// ============================================================================
// Multer Configuration for File Uploads
// ============================================================================
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// ============================================================================
// Database Setup
// ============================================================================
const db = new Database('phonegpt.db');

// Initialize all database tables
db.exec(`
  -- Users table
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    name TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
  );

  -- Chat sessions (web interface)
  CREATE TABLE IF NOT EXISTS chatSessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL,
    sessionName TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
  );

  -- Chat messages
  CREATE TABLE IF NOT EXISTS chatMessages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionId INTEGER NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sessionId) REFERENCES chatSessions(id) ON DELETE CASCADE
  );

  -- Glass sessions (MentraOS glasses)
  CREATE TABLE IF NOT EXISTS glassSessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL,
    sessionName TEXT NOT NULL,
    deviceId TEXT,
    persona TEXT DEFAULT 'work',
    wpm INTEGER DEFAULT 180,
    is_active BOOLEAN DEFAULT 0,
    is_paused BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
  );

  -- Glass conversations (Q&A pairs from glasses)
  CREATE TABLE IF NOT EXISTS glassConversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionId INTEGER NOT NULL,
    query TEXT NOT NULL,
    response TEXT NOT NULL,
    responsePages TEXT,
    currentPage INTEGER DEFAULT 0,
    duration INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sessionId) REFERENCES glassSessions(id) ON DELETE CASCADE
  );

  -- Documents with persona support
  CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL,
    fileName TEXT NOT NULL,
    content TEXT NOT NULL,
    persona TEXT DEFAULT 'work',
    embedding BLOB,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
  );

  -- User personas settings
  CREATE TABLE IF NOT EXISTS userPersonas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL,
    persona TEXT NOT NULL,
    settings TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(userId, persona),
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
  );

  -- MentraOS devices
  CREATE TABLE IF NOT EXISTS mentraosDevices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    deviceId TEXT UNIQUE NOT NULL,
    userId INTEGER NOT NULL,
    sessionId INTEGER,
    deviceModel TEXT,
    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_sync DATETIME,
    battery_level INTEGER,
    is_connected BOOLEAN DEFAULT 1,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (sessionId) REFERENCES glassSessions(id) ON DELETE CASCADE
  );

  -- Transcription notes for each persona
  CREATE TABLE IF NOT EXISTS transcriptionNotes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER NOT NULL,
    persona TEXT NOT NULL,
    title TEXT,
    transcript TEXT NOT NULL,
    summary TEXT,
    duration INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
  );
`);

const checkAndAddColumns = () => {
  try {
    // Check if columns already exist
    const tableInfo = db.prepare("PRAGMA table_info(glassSessions)").all();
    const columnNames = tableInfo.map((col: any) => col.name);
    
    // Add page_display_duration if it doesn't exist
    if (!columnNames.includes('page_display_duration')) {
      db.exec('ALTER TABLE glassSessions ADD COLUMN page_display_duration INTEGER DEFAULT 5000');
      console.log('✅ Added page_display_duration column to glassSessions');
    }
    
    // Add auto_advance_pages if it doesn't exist
    if (!columnNames.includes('auto_advance_pages')) {
      db.exec('ALTER TABLE glassSessions ADD COLUMN auto_advance_pages BOOLEAN DEFAULT 1');
      console.log('✅ Added auto_advance_pages column to glassSessions');
    }
  } catch (error) {
    console.log('Database columns already exist or error adding them:', error);
  }
};

// Call this after creating the initial tables
checkAndAddColumns();

// ============================================================================
// Type Definitions
// ============================================================================
interface ConversationMessage {
  id: string;
  timestamp: string;
  query: string;
  response: string;
  pages: string[];
  currentPage: number;
}

interface SessionState {
  sessionId: string;
  userId: string;
  session: AppSession;
  state: 'listening' | 'processing' | 'displaying' | 'paused';
  currentTranscript: string;
  lastResponse: string;
  conversation: ConversationMessage[];
  currentPageIndex: number;
  isPaused: boolean;
  displayDuration: number;
  wpm: number;
  dbSessionId?: number;
  autoAdvancePages: boolean;
  pageDisplayDuration: number;
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

interface JWTPayload {
  userId: number;
  email: string;
}

// ============================================================================
// Authentication Middleware
// ============================================================================
function authenticateToken(req: any, res: Response, next: any) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err: any, user: any) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
}

// ============================================================================
// PhoneGPT MentraOS App Class
// ============================================================================
class PhoneGPTMentraOSApp extends AppServer {
  private sessions: Map<string, SessionState> = new Map();
  private eventQueue: QueuedEvent[] = [];
  private readonly MAX_QUEUE_SIZE = 1000;

  constructor() {
    super({
      packageName: PACKAGE_NAME,
      apiKey: MENTRAOS_API_KEY,
      port: PORT,
    });

    this.setupExpress();
  }

  private setupExpress() {
    const app = (this as any).app;
    
    if (!app) {
      console.error('❌ Failed to get Express app from AppServer');
      return;
    }

    // CRITICAL: Prevent 304 caching on API routes
    app.use((req: any, res: any, next: any) => {
      if (req.path.startsWith('/api/')) {
        delete req.headers['if-none-match'];
        delete req.headers['if-modified-since'];
        res.set({
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
          'Surrogate-Control': 'no-store'
        });
      }
      next();
    });

    // CORS Configuration
    app.use(cors({
      origin: function(origin: any, callback: any) {
        callback(null, true); // Allow all origins for development
      },
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization']
    }));

    // JSON parsing
    app.use(express.json());

    // Request logging
    app.use((req: Request, res: Response, next: any) => {
      const start = Date.now();
      const originalEnd = res.end;

      res.end = function(...args: any[]) {
        const duration = Date.now() - start;
        const statusColor = res.statusCode >= 400 ? '❌' : '✅';
        console.log(`${statusColor} ${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`);
        return originalEnd.apply(res, args);
      };

      next();
    });

    // ======================================================================
    // Authentication Endpoints
    // ======================================================================

    app.post('/api/auth/signup', async (req: Request, res: Response) => {
      try {
        const { email, password, name } = req.body;

        if (!email || !password) {
          return res.status(400).json({ error: 'Email and password required' });
        }

        const existingUser = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
        if (existingUser) {
          return res.status(409).json({ error: 'User already exists' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const result = db.prepare(
          'INSERT INTO users (email, password, name) VALUES (?, ?, ?)'
        ).run(email, hashedPassword, name || null);

        // Create default chat session
        db.prepare(
          'INSERT INTO chatSessions (userId, sessionName) VALUES (?, ?)'
        ).run(result.lastInsertRowid, 'Main Session');

        const token = jwt.sign(
          { userId: result.lastInsertRowid, email },
          JWT_SECRET,
          { expiresIn: '30d' }
        );

        res.status(201).json({
          message: 'User created successfully',
          token,
          user: {
            id: result.lastInsertRowid,
            email,
            name
          }
        });
      } catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/auth/login', async (req: Request, res: Response) => {
      try {
        const { email, password } = req.body;

        if (!email || !password) {
          return res.status(400).json({ error: 'Email and password required' });
        }

        const user: any = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
        if (!user) {
          return res.status(401).json({ error: 'Invalid credentials' });
        }

        const isValid = await bcrypt.compare(password, user.password);
        if (!isValid) {
          return res.status(401).json({ error: 'Invalid credentials' });
        }

        db.prepare('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?')
          .run(user.id);

        const token = jwt.sign(
          { userId: user.id, email: user.email },
          JWT_SECRET,
          { expiresIn: '30d' }
        );

        res.json({
          message: 'Login successful',
          token,
          user: {
            id: user.id,
            email: user.email,
            name: user.name
          }
        });
      } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.get('/api/auth/verify', authenticateToken, (req: any, res: Response) => {
      const user = db.prepare('SELECT id, email, name FROM users WHERE id = ?')
        .get(req.user.userId);
      
      res.json({ 
        valid: true, 
        user 
      });
    });

    // ======================================================================
    // Glass Sessions CRUD Endpoints
    // ======================================================================

    app.get('/api/glass-sessions', authenticateToken, (req: any, res: Response) => {
      try {
        const sessions = db.prepare(
          'SELECT * FROM glassSessions WHERE userId = ? ORDER BY updated_at DESC'
        ).all(req.user.userId);
        
        res.json(sessions || []);
      } catch (error) {
        console.error('Get glass sessions error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/glass-sessions', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionName, persona, wpm } = req.body;
        
        const result = db.prepare(
          'INSERT INTO glassSessions (userId, sessionName, persona, wpm) VALUES (?, ?, ?, ?)'
        ).run(req.user.userId, sessionName || `Glass Session ${Date.now()}`, persona || 'work', wpm || 180);
        
        res.status(201).json({
          id: result.lastInsertRowid,
          sessionName,
          persona,
          wpm
        });
      } catch (error) {
        console.error('Create glass session error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.delete('/api/glass-sessions/:sessionId', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        
        const session = db.prepare(
          'SELECT * FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        db.prepare('DELETE FROM glassSessions WHERE id = ?').run(sessionId);
        res.json({ message: 'Session deleted' });
      } catch (error) {
        console.error('Delete glass session error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // ======================================================================
    // Glass Conversations Endpoints
    // ======================================================================

    app.get('/api/glass-sessions/:sessionId/conversations', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        
        const session = db.prepare(
          'SELECT * FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        const conversations = db.prepare(
          'SELECT * FROM glassConversations WHERE sessionId = ? ORDER BY timestamp DESC'
        ).all(sessionId);
        
        res.json(conversations || []);
      } catch (error) {
        console.error('Get conversations error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/glass-sessions/:sessionId/conversations', authenticateToken, async (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        const { query, response, responsePages, duration } = req.body;
        
        const session = db.prepare(
          'SELECT * FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        const result = db.prepare(
          'INSERT INTO glassConversations (sessionId, query, response, responsePages, duration) VALUES (?, ?, ?, ?, ?)'
        ).run(sessionId, query, response, JSON.stringify(responsePages || []), duration || 0);
        
        db.prepare('UPDATE glassSessions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(sessionId);
        
        res.status(201).json({
          id: result.lastInsertRowid,
          query,
          response,
          responsePages,
          duration
        });
      } catch (error) {
        console.error('Create conversation error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // ======================================================================
    // Glass Session Settings
    // ======================================================================

    app.post('/api/glass-sessions/:sessionId/settings', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        const { wpm, persona } = req.body;
        
        const session = db.prepare(
          'SELECT * FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        if (wpm !== undefined) {
          db.prepare('UPDATE glassSessions SET wpm = ? WHERE id = ?').run(wpm, sessionId);
        }
        
        if (persona !== undefined) {
          db.prepare('UPDATE glassSessions SET persona = ? WHERE id = ?').run(persona, sessionId);
        }
        
        res.json({ message: 'Settings updated' });
      } catch (error) {
        console.error('Update settings error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // ======================================================================
    // Glass Session Controls (Pause/Resume)
    // ======================================================================

    app.post('/api/glass-sessions/:sessionId/pause', authenticateToken, async (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        
        db.prepare('UPDATE glassSessions SET is_paused = 1 WHERE id = ?').run(sessionId);
        
        // Also pause the actual MentraOS glass if connected
        const glassState = this.sessions.get(sessionId.toString());
        if (glassState) {
          glassState.isPaused = true;
          glassState.state = 'paused';
          glassState.session.layouts.showTextWall('🔇 Listening Paused', {
            view: ViewType.MAIN,
            durationMs: 2000,
          });
        }
        
        res.json({ status: 'paused', sessionId });
      } catch (error) {
        console.error('Pause error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/glass-sessions/:sessionId/resume', authenticateToken, async (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        
        db.prepare('UPDATE glassSessions SET is_paused = 0 WHERE id = ?').run(sessionId);
        
        // Also resume the actual MentraOS glass if connected
        const glassState = this.sessions.get(sessionId.toString());
        if (glassState) {
          glassState.isPaused = false;
          glassState.state = 'listening';
          glassState.session.layouts.showTextWall('🎤 Listening Resumed', {
            view: ViewType.MAIN,
            durationMs: 2000,
          });
        }
        
        res.json({ status: 'resumed', sessionId });
      } catch (error) {
        console.error('Resume error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Page navigation for responses
    app.post('/api/glass-sessions/:sessionId/next-page', authenticateToken, (req: any, res: Response) => {
      const { sessionId } = req.params;
      const glassState = this.sessions.get(sessionId.toString());
      
      if (!glassState) {
        return res.status(404).json({ error: 'Glass session not found' });
      }
      
      const lastMessage = glassState.conversation[glassState.conversation.length - 1];
      if (!lastMessage || glassState.currentPageIndex >= lastMessage.pages.length - 1) {
        return res.status(400).json({ error: 'No next page' });
      }
      
      glassState.currentPageIndex++;
      this.displayPage(glassState.session, lastMessage.pages[glassState.currentPageIndex], 
                      glassState.displayDuration, lastMessage.pages.length, glassState.currentPageIndex);
      
      res.json({ currentPage: glassState.currentPageIndex, totalPages: lastMessage.pages.length });
    });

    app.post('/api/glass-sessions/:sessionId/page-settings', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        const { pageDisplayDuration, autoAdvance } = req.body;
        
        const session = db.prepare(
          'SELECT * FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        // Update page display settings
        if (pageDisplayDuration !== undefined) {
          db.prepare('UPDATE glassSessions SET page_display_duration = ? WHERE id = ?')
            .run(pageDisplayDuration, sessionId);
          
          // Update active glass session if connected
          const glassState = this.sessions.get(sessionId.toString());
          if (glassState) {
            glassState.pageDisplayDuration = pageDisplayDuration;
          }
        }
        
        if (autoAdvance !== undefined) {
          db.prepare('UPDATE glassSessions SET auto_advance_pages = ? WHERE id = ?')
            .run(autoAdvance ? 1 : 0, sessionId);
          
          const glassState = this.sessions.get(sessionId.toString());
          if (glassState) {
            glassState.autoAdvancePages = autoAdvance;
          }
        }
        
        res.json({ message: 'Page settings updated' });
      } catch (error) {
        console.error('Update page settings error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.get('/api/glass-sessions/:sessionId/persona', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        
        const session = db.prepare(
          'SELECT persona FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        // Also get documents for this persona
        const documents = db.prepare(
          'SELECT fileName, created_at FROM documents WHERE userId = ? AND persona = ?'
        ).all(req.user.userId, (session as any).persona);
        
        res.json({
          persona: (session as any).persona,
          documentCount: documents.length,
          documents: documents
        });
      } catch (error) {
        console.error('Get persona error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/glass-sessions/:sessionId/switch-persona', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        const { persona } = req.body;
        
        const session = db.prepare(
          'SELECT * FROM glassSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);
        
        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }
        
        // Update persona
        db.prepare('UPDATE glassSessions SET persona = ? WHERE id = ?').run(persona, sessionId);
        
        // Update active glass session if connected
        const glassState = this.sessions.get(sessionId.toString());
        if (glassState) {
          // Update the persona in memory
          (glassState as any).persona = persona;
        }
        
        res.json({ 
          message: 'Persona switched successfully',
          persona: persona
        });
      } catch (error) {
        console.error('Switch persona error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/glass-sessions/:sessionId/prev-page', authenticateToken, (req: any, res: Response) => {
      const { sessionId } = req.params;
      const glassState = this.sessions.get(sessionId.toString());
      
      if (!glassState) {
        return res.status(404).json({ error: 'Glass session not found' });
      }
      
      const lastMessage = glassState.conversation[glassState.conversation.length - 1];
      if (!lastMessage || glassState.currentPageIndex <= 0) {
        return res.status(400).json({ error: 'No previous page' });
      }
      
      glassState.currentPageIndex--;
      this.displayPage(glassState.session, lastMessage.pages[glassState.currentPageIndex], 
                      glassState.displayDuration, lastMessage.pages.length, glassState.currentPageIndex);
      
      res.json({ currentPage: glassState.currentPageIndex, totalPages: lastMessage.pages.length });
    });

    // ======================================================================
    // Document Management with PDF Support
    // ======================================================================

app.post('/api/documents', authenticateToken, upload.single('file'), async (req: any, res: Response) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const fileName = req.file.originalname;
    const fileBuffer = req.file.buffer;
    const mimeType = req.file.mimetype;
    const persona = req.body.persona || 'home';
    
    console.log(`📤 Processing upload: ${fileName} (${mimeType}) for ${persona} persona`);
    
    let extractedText = '';
    
    // Extract text based on file type
    try {
      if (mimeType === 'application/pdf' || fileName.toLowerCase().endsWith('.pdf')) {
        // Extract text from PDF using PDFParse class
        console.log('📄 Extracting text from PDF...');
        
        // Create parser instance with the buffer
        const parser = new PDFParse({ data: fileBuffer });
        
        // Get the text
        const result = await parser.getText();
        extractedText = result.text;
        
        // Important: destroy the parser to free memory
        await parser.destroy();
        
        console.log(`✅ Extracted ${extractedText.length} characters from PDF`);
        
      } else if (mimeType.startsWith('text/') || 
                 fileName.toLowerCase().endsWith('.txt') ||
                 fileName.toLowerCase().endsWith('.md') ||
                 fileName.toLowerCase().endsWith('.csv') ||
                 fileName.toLowerCase().endsWith('.json')) {
        // Text-based files
        console.log('📄 Processing text file...');
        extractedText = fileBuffer.toString('utf-8');
        console.log(`✅ Read ${extractedText.length} characters from text file`);
        
      } else {
        // Try to extract as text anyway
        console.log('📄 Attempting text extraction...');
        extractedText = fileBuffer.toString('utf-8');
        
        // Check if we got readable text
        const readableChars = extractedText.replace(/[^\x20-\x7E\n\r\t]/g, '').length;
        const totalChars = extractedText.length;
        const readableRatio = readableChars / totalChars;
        
        if (readableRatio < 0.8) {
          return res.status(400).json({ 
            error: `File appears to be binary. Please upload PDF, TXT, MD, CSV, or JSON files.` 
          });
        }
      }
    } catch (extractError: any) {
      console.error('❌ Text extraction failed:', extractError);
      console.error('Error details:', extractError.message);
      return res.status(400).json({ 
        error: 'Failed to extract text from document. Error: ' + extractError.message 
      });
    }
    
    // Validate we got actual text
    if (!extractedText || extractedText.trim().length === 0) {
      return res.status(400).json({ 
        error: 'No text content found in document' 
      });
    }
    
    // Store in database
    const result = db.prepare(
      'INSERT INTO documents (userId, fileName, content, persona) VALUES (?, ?, ?, ?)'
    ).run(req.user.userId, fileName, extractedText, persona);
    
    const wordCount = extractedText.split(/\s+/).length;
    
    console.log(`✅ Document saved: ${fileName}`);
    console.log(`   - ID: ${result.lastInsertRowid}`);
    console.log(`   - Persona: ${persona}`);
    console.log(`   - Words: ${wordCount}`);
    console.log(`   - Characters: ${extractedText.length}`);
    
    res.status(201).json({
      id: result.lastInsertRowid,
      fileName,
      persona,
      wordCount,
      characterCount: extractedText.length,
      message: `Document uploaded successfully to ${persona} persona`
    });
  } catch (error) {
    console.error('Upload document error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

    app.get('/api/documents', authenticateToken, (req: any, res: Response) => {
      try {
        const { persona } = req.query;
        
        let query = 'SELECT id, fileName, persona, created_at FROM documents WHERE userId = ?';
        const params = [req.user.userId];
        
        if (persona) {
          query += ' AND persona = ?';
          params.push(persona as string);
        }
        
        query += ' ORDER BY created_at DESC';
        
        const documents = db.prepare(query).all(...params);
        res.json(documents);
      } catch (error) {
        console.error('Get documents error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.delete('/api/documents/:documentId', authenticateToken, (req: any, res: Response) => {
      try {
        const { documentId } = req.params;
        
        const doc = db.prepare(
          'SELECT * FROM documents WHERE id = ? AND userId = ?'
        ).get(documentId, req.user.userId);
        
        if (!doc) {
          return res.status(404).json({ error: 'Document not found' });
        }
        
        db.prepare('DELETE FROM documents WHERE id = ?').run(documentId);
        res.json({ message: 'Document deleted' });
      } catch (error) {
        console.error('Delete document error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.get('/api/debug/documents/:persona', authenticateToken, (req: any, res: Response) => {
      try {
        const { persona } = req.params;
        
        const documents = db.prepare(
          'SELECT id, fileName, persona, LENGTH(content) as contentLength, created_at FROM documents WHERE userId = ? AND persona = ?'
        ).all(req.user.userId, persona);
        
        const sessions = db.prepare(
          'SELECT id, sessionName, persona, is_active FROM glassSessions WHERE userId = ? AND persona = ?'
        ).all(req.user.userId, persona);
        
        res.json({
          persona,
          documentCount: documents.length,
          documents,
          sessionsInPersona: sessions.length,
          sessions,
          debug: {
            userId: req.user.userId,
            timestamp: new Date().toISOString()
          }
        });
      } catch (error) {
        console.error('Debug error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });
    // ======================================================================
    // Transcription Notes Endpoints
    // ======================================================================

    // Get all transcription notes for a persona
    app.get('/api/transcription-notes/:persona', authenticateToken, (req: any, res: Response) => {
      try {
        const { persona } = req.params;
        
        const notes = db.prepare(
          `SELECT id, title, transcript, summary, duration, created_at 
          FROM transcriptionNotes 
          WHERE userId = ? AND persona = ? 
          ORDER BY created_at DESC`
        ).all(req.user.userId, persona);
        
        res.json(notes || []);
      } catch (error) {
        console.error('Get transcription notes error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Create a new transcription note
    app.post('/api/transcription-notes', authenticateToken, async (req: any, res: Response) => {
      try {
        const { persona, title, transcript, duration } = req.body;
        
        if (!transcript) {
          return res.status(400).json({ error: 'Transcript is required' });
        }
        
        const result = db.prepare(
          `INSERT INTO transcriptionNotes 
          (userId, persona, title, transcript, duration) 
          VALUES (?, ?, ?, ?, ?)`
        ).run(
          req.user.userId,
          persona || 'work',
          title || `Note from ${new Date().toLocaleString()}`,
          transcript,
          duration || 0
        );
        
        res.status(201).json({
          id: result.lastInsertRowid,
          message: 'Transcription note created successfully'
        });
      } catch (error) {
        console.error('Create transcription note error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Generate AI summary for a transcription
    app.post('/api/transcription-notes/:noteId/summarize', authenticateToken, async (req: any, res: Response) => {
      try {
        const { noteId } = req.params;
        
        // Get the transcription note
        const note: any = db.prepare(
          `SELECT * FROM transcriptionNotes 
          WHERE id = ? AND userId = ?`
        ).get(noteId, req.user.userId);
        
        if (!note) {
          return res.status(404).json({ error: 'Transcription note not found' });
        }
        
        // Generate AI summary
        console.log(`🤖 Generating summary for note ${noteId}`);
        
        const systemPrompt = `You are a helpful assistant that creates concise summaries of conversations. 
        Extract the key points, decisions, and action items from the following transcript.
        Keep the summary brief but comprehensive - ideally 3-5 bullet points.`;
        
        const message = await anthropic.messages.create({
          model: LLM_MODEL,
          max_tokens: 300,
          messages: [{
            role: 'user',
            content: `${systemPrompt}\n\nTranscript:\n${note.transcript}\n\nSummary:`
          }]
        });

        const summary = message.content[0].type === 'text' 
          ? message.content[0].text 
          : 'Unable to generate summary';
        
        // Update the note with the summary
        db.prepare(
          `UPDATE transcriptionNotes 
          SET summary = ?, updated_at = CURRENT_TIMESTAMP 
          WHERE id = ?`
        ).run(summary, noteId);
        
        res.json({
          summary,
          message: 'Summary generated successfully'
        });
      } catch (error) {
        console.error('Generate summary error:', error);
        res.status(500).json({ error: 'Failed to generate summary' });
      }
    });

    // Update a transcription note
    app.put('/api/transcription-notes/:noteId', authenticateToken, (req: any, res: Response) => {
      try {
        const { noteId } = req.params;
        const { title, transcript, summary } = req.body;
        
        const note = db.prepare(
          `SELECT * FROM transcriptionNotes 
          WHERE id = ? AND userId = ?`
        ).get(noteId, req.user.userId);
        
        if (!note) {
          return res.status(404).json({ error: 'Transcription note not found' });
        }
        
        // Build update query dynamically
        const updates = [];
        const params = [];
        
        if (title !== undefined) {
          updates.push('title = ?');
          params.push(title);
        }
        if (transcript !== undefined) {
          updates.push('transcript = ?');
          params.push(transcript);
        }
        if (summary !== undefined) {
          updates.push('summary = ?');
          params.push(summary);
        }
        
        if (updates.length === 0) {
          return res.status(400).json({ error: 'No fields to update' });
        }
        
        updates.push('updated_at = CURRENT_TIMESTAMP');
        params.push(noteId);
        
        db.prepare(
          `UPDATE transcriptionNotes 
          SET ${updates.join(', ')} 
          WHERE id = ?`
        ).run(...params);
        
        res.json({ message: 'Transcription note updated successfully' });
      } catch (error) {
        console.error('Update transcription note error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Delete a transcription note
    app.delete('/api/transcription-notes/:noteId', authenticateToken, (req: any, res: Response) => {
      try {
        const { noteId } = req.params;
        
        const note = db.prepare(
          `SELECT * FROM transcriptionNotes 
          WHERE id = ? AND userId = ?`
        ).get(noteId, req.user.userId);
        
        if (!note) {
          return res.status(404).json({ error: 'Transcription note not found' });
        }
        
        db.prepare('DELETE FROM transcriptionNotes WHERE id = ?').run(noteId);
        
        res.json({ message: 'Transcription note deleted successfully' });
      } catch (error) {
        console.error('Delete transcription note error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Batch create from glass conversation
    app.post('/api/transcription-notes/from-conversation', authenticateToken, async (req: any, res: Response) => {
      try {
        const { conversationId, persona } = req.body;
        
        // Get the glass conversation
        const conversation: any = db.prepare(
          `SELECT gc.*, gs.persona 
          FROM glassConversations gc
          JOIN glassSessions gs ON gc.sessionId = gs.id
          WHERE gc.id = ? AND gs.userId = ?`
        ).get(conversationId, req.user.userId);
        
        if (!conversation) {
          return res.status(404).json({ error: 'Conversation not found' });
        }
        
        // Create a transcription note from the conversation
        const transcript = `Q: ${conversation.query}\n\nA: ${conversation.response}`;
        const title = `Glass: ${conversation.query.substring(0, 50)}${conversation.query.length > 50 ? '...' : ''}`;
        
        const result = db.prepare(
          `INSERT INTO transcriptionNotes 
          (userId, persona, title, transcript, duration, created_at) 
          VALUES (?, ?, ?, ?, ?, ?)`
        ).run(
          req.user.userId,
          persona || conversation.persona,
          title,
          transcript,
          conversation.duration || 0,
          conversation.timestamp
        );
        
        res.status(201).json({
          id: result.lastInsertRowid,
          message: 'Transcription note created from conversation'
        });
      } catch (error) {
        console.error('Create from conversation error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });
    // ======================================================================
    // Chat Sessions (Web Interface)
    // ======================================================================

    app.get('/api/sessions', authenticateToken, (req: any, res: Response) => {
      try {
        const sessions = db.prepare(
          'SELECT * FROM chatSessions WHERE userId = ? ORDER BY updated_at DESC'
        ).all(req.user.userId);

        res.status(200).json(sessions || []);
      } catch (error) {
        console.error('Get sessions error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/sessions', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionName } = req.body;
        
        const result = db.prepare(
          'INSERT INTO chatSessions (userId, sessionName) VALUES (?, ?)'
        ).run(req.user.userId, sessionName || `Session ${Date.now()}`);

        res.status(201).json({
          id: result.lastInsertRowid,
          sessionName: sessionName || `Session ${Date.now()}`
        });
      } catch (error) {
        console.error('Create session error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.get('/api/sessions/:sessionId/messages', authenticateToken, (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;

        const session = db.prepare(
          'SELECT * FROM chatSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);

        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }

        const messages = db.prepare(
          'SELECT * FROM chatMessages WHERE sessionId = ? ORDER BY timestamp ASC'
        ).all(sessionId);

        res.json(messages);
      } catch (error) {
        console.error('Get messages error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    app.post('/api/sessions/:sessionId/messages', authenticateToken, async (req: any, res: Response) => {
      try {
        const { sessionId } = req.params;
        const { content, role = 'user' } = req.body;

        const session = db.prepare(
          'SELECT * FROM chatSessions WHERE id = ? AND userId = ?'
        ).get(sessionId, req.user.userId);

        if (!session) {
          return res.status(404).json({ error: 'Session not found' });
        }

        const userMsgResult = db.prepare(
          'INSERT INTO chatMessages (sessionId, role, content) VALUES (?, ?, ?)'
        ).run(sessionId, role, content);

        if (role === 'user') {
          try {
            const history = db.prepare(
              'SELECT role, content FROM chatMessages WHERE sessionId = ? ORDER BY timestamp DESC LIMIT 20'
            ).all(sessionId);

            const messages = history.reverse().map(msg => ({
              role: msg.role === 'user' ? 'user' : 'assistant',
              content: msg.content
            }));

            messages.push({ role: 'user', content });

            const response = await anthropic.messages.create({
              model: LLM_MODEL,
              messages: messages as any,
              max_tokens: 1024,
            });

            const aiContent = response.content[0].type === 'text' 
              ? response.content[0].text 
              : 'Sorry, I could not generate a response.';

            const aiMsgResult = db.prepare(
              'INSERT INTO chatMessages (sessionId, role, content) VALUES (?, ?, ?)'
            ).run(sessionId, 'assistant', aiContent);

            db.prepare('UPDATE chatSessions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?')
              .run(sessionId);

            res.status(201).json({
              userMessage: {
                id: userMsgResult.lastInsertRowid,
                role: 'user',
                content
              },
              assistantMessage: {
                id: aiMsgResult.lastInsertRowid,
                role: 'assistant',
                content: aiContent
              }
            });
          } catch (aiError) {
            console.error('AI generation error:', aiError);
            res.status(201).json({
              userMessage: {
                id: userMsgResult.lastInsertRowid,
                role: 'user',
                content
              },
              error: 'Failed to generate AI response'
            });
          }
        } else {
          res.status(201).json({
            id: userMsgResult.lastInsertRowid,
            role,
            content
          });
        }
      } catch (error) {
        console.error('Send message error:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // ======================================================================
    // Other Endpoints
    // ======================================================================

    app.get('/api/health', (req: Request, res: Response) => {
      res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        glassSessionsActive: this.sessions.size,
        databaseConnected: true
      });
    });

    app.get('/api/events', (req: Request, res: Response) => {
      const since = parseInt(req.query.since as string) || 0;
      const limit = parseInt(req.query.limit as string) || 100;
      const newEvents = this.eventQueue.slice(since, since + limit);

      res.json({
        events: newEvents,
        count: this.eventQueue.length,
        last_index: Math.min(since + newEvents.length, this.eventQueue.length),
      });
    });

    app.get('/api/stats', (req: Request, res: Response) => {
      const eventTypes: Record<string, number> = {};
      for (const event of this.eventQueue) {
        eventTypes[event.type] = (eventTypes[event.type] || 0) + 1;
      }

      res.json({
        total_events: this.eventQueue.length,
        event_types: eventTypes,
        active_glass_sessions: this.sessions.size,
        timestamp: new Date().toISOString(),
      });
    });

    console.log('✅ Express endpoints configured successfully');
  }

  // ============================================================================
  // MentraOS Glass Session Handling
  // ============================================================================

  protected async onSession(session: AppSession, sessionId: string, userId: string): Promise<void> {
    console.log('\n' + '='.repeat(60));
    console.log('🔵 NEW GLASS SESSION STARTED');
    console.log(`   Session ID: ${sessionId}`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Timestamp: ${new Date().toISOString()}`);
    console.log('='.repeat(60) + '\n');

    // Try to find existing user by device ID mapping
    let dbUserId = 1; // Default to user 1 for now
    const device = db.prepare('SELECT userId FROM mentraosDevices WHERE deviceId = ?').get(sessionId);
    if (device) {
      dbUserId = (device as any).userId;
    }

    // Find or create glass session in database
    let dbSession: any = db.prepare(
      'SELECT * FROM glassSessions WHERE deviceId = ? ORDER BY created_at DESC LIMIT 1'
    ).get(sessionId);
    
    if (!dbSession) {
      // Create new session with current persona (default to 'home')
      const result = db.prepare(
        'INSERT INTO glassSessions (userId, sessionName, deviceId, persona, is_active) VALUES (?, ?, ?, ?, 1)'
      ).run(dbUserId, `Glass Session ${new Date().toLocaleString()}`, sessionId, 'home');
      dbSession = db.prepare('SELECT * FROM glassSessions WHERE id = ?').get(result.lastInsertRowid);
    } else {
      // Mark session as active
      db.prepare('UPDATE glassSessions SET is_active = 1 WHERE id = ?').run(dbSession.id);
    }

    console.log(`📁 Session persona: ${dbSession.persona}`);

    const sessionState: SessionState = {
      sessionId,
      userId,
      session,
      state: 'listening',
      currentTranscript: '',
      lastResponse: '',
      conversation: [],
      currentPageIndex: 0,
      isPaused: false,
      displayDuration: 5000,
      wpm: dbSession.wpm || 180,
      dbSessionId: dbSession.id,
      autoAdvancePages: true,
      pageDisplayDuration: dbSession.page_display_duration || 5000,
      eventHistory: [],
    };

    this.sessions.set(sessionId, sessionState);
    this.addEvent('glass_connected', { sessionId, userId }, sessionId);

    session.layouts.showTextWall(`✨ PhoneGPT Connected\n\n${dbSession.persona.toUpperCase()} Mode Active\n\nReady for voice commands!`, {
      view: ViewType.MAIN,
      durationMs: 3000,
    });

    // Setup transcription listener with PROPER PAGINATION
    session.events.onTranscription(async (data) => {
      if (sessionState.isPaused) {
        console.log('🔇 Microphone paused - ignoring voice input');
        return;
      }

      if (data.isFinal) {
        const transcript = data.text.trim();
        console.log(`🎤 Voice: "${transcript}"`);
        
        this.addEvent('voice_input', { transcript, sessionId }, sessionId);
        sessionState.state = 'processing';
        
        session.layouts.showTextWall(`🤔 Processing...`, {
          view: ViewType.MAIN,
          durationMs: 2000,
        });

        // Generate AI response with documents
        const aiResponse = await this.generateAIResponseWithDocuments(
          transcript, 
          dbSession.persona, 
          dbSession.userId
        );
        
        const pages = this.paginateText(aiResponse, 150);
        
        const conversationEntry: ConversationMessage = {
          id: `msg_${Date.now()}`,
          timestamp: new Date().toISOString(),
          query: transcript,
          response: aiResponse,
          pages,
          currentPage: 0
        };

        sessionState.conversation.push(conversationEntry);
        sessionState.lastResponse = aiResponse;
        sessionState.currentPageIndex = 0;
        sessionState.state = 'displaying';

        // Save conversation to database
        db.prepare(
          'INSERT INTO glassConversations (sessionId, query, response, responsePages) VALUES (?, ?, ?, ?)'
        ).run(sessionState.dbSessionId, transcript, aiResponse, JSON.stringify(pages));
        
        // Update session activity
        db.prepare('UPDATE glassSessions SET updated_at = CURRENT_TIMESTAMP WHERE id = ?')
          .run(sessionState.dbSessionId);

        // ===== PAGINATION AUTO-ADVANCE LOGIC =====
        console.log(`📄 Response has ${pages.length} page(s)`);
        
        if (pages.length > 1) {
          // Multiple pages - auto-advance through them
          console.log(`⏱️ Auto-advancing through ${pages.length} pages at ${sessionState.pageDisplayDuration}ms per page`);
          
          // Display first page
          this.displayPage(session, pages[0], sessionState.pageDisplayDuration, pages.length, 0);
          
          // Schedule remaining pages
          for (let i = 1; i < pages.length; i++) {
            setTimeout(() => {
              // Check if still in displaying state and not paused
              if (sessionState.state === 'displaying' && !sessionState.isPaused) {
                sessionState.currentPageIndex = i;
                console.log(`📄 Displaying page ${i + 1}/${pages.length}`);
                this.displayPage(session, pages[i], sessionState.pageDisplayDuration, pages.length, i);
                
                // After last page, return to listening state
                if (i === pages.length - 1) {
                  setTimeout(() => {
                    if (!sessionState.isPaused) {
                      sessionState.state = 'listening';
                      console.log('✅ Returned to listening state');
                    }
                  }, sessionState.pageDisplayDuration);
                }
              }
            }, sessionState.pageDisplayDuration * i);
          }
        } else {
          // Single page response
          console.log('📄 Single page response');
          this.displayPage(session, pages[0], sessionState.pageDisplayDuration, 1, 0);
          
          // Return to listening after display duration
          setTimeout(() => {
            if (!sessionState.isPaused) {
              sessionState.state = 'listening';
              console.log('✅ Returned to listening state');
            }
          }, sessionState.pageDisplayDuration);
        }

        this.addEvent('ai_response', { 
          query: transcript, 
          response: aiResponse, 
          pageCount: pages.length, 
          sessionId 
        }, sessionId);
      }
    });

    session.events.onDisconnected(() => {
      console.log(`🔴 Glass session ended: ${sessionId}`);
      this.addEvent('glass_disconnected', { sessionId }, sessionId);
      
      if (sessionState.dbSessionId) {
        db.prepare('UPDATE glassSessions SET is_active = 0 WHERE id = ?').run(sessionState.dbSessionId);
      }
      
      this.sessions.delete(sessionId);
    });
  }

  private async generateAIResponseWithDocuments(transcript: string, persona: string, userId: number): Promise<string> {
    try {
      console.log(`🤖 Generating AI response for persona: ${persona}, userId: ${userId}`);
      
      // Get ALL documents for this persona
      const documents = db.prepare(
        'SELECT fileName, content FROM documents WHERE userId = ? AND persona = ? ORDER BY created_at DESC'
      ).all(userId, persona);
      
      console.log(`📚 Found ${documents.length} documents in ${persona} persona`);
      
      // Build comprehensive document context
      let documentContext = '';
      const documentList: string[] = [];
      
      if (documents.length > 0) {
        documentContext = `\n=== UPLOADED DOCUMENTS IN ${persona.toUpperCase()} CONTEXT ===\n\n`;
        
        documents.forEach((doc: any, index: number) => {
          documentList.push(doc.fileName);
          documentContext += `📄 Document ${index + 1}: "${doc.fileName}"\n`;
          documentContext += `Content:\n${doc.content}\n\n`;
          documentContext += '---\n\n';
        });
        
        documentContext += `\n=== END OF DOCUMENTS ===\n\n`;
        documentContext += `IMPORTANT INSTRUCTIONS:\n`;
        documentContext += `1. You have access to ${documents.length} document(s) listed above.\n`;
        documentContext += `2. When the user asks about documents, uploaded files, or references content, USE the document content above to answer.\n`;
        documentContext += `3. If asked to summarize, provide a comprehensive summary of the relevant document.\n`;
        documentContext += `4. Always mention which document you're referencing by name.\n`;
        documentContext += `5. Be specific and quote relevant sections when appropriate.\n\n`;
      }
      
      // Check if query is document-related
      const documentKeywords = [
        'document', 'file', 'upload', 'pdf', 'guide', 'summarize', 
        'summary', 'what does', 'what is', 'tell me about', 'explain',
        'nutrition', 'manley', 'performance'
      ];
      
      const isDocumentQuery = documentKeywords.some(keyword => 
        transcript.toLowerCase().includes(keyword)
      );
      
      // Build the prompt
      let systemPrompt = `You are PhoneGPT, an AI assistant operating in ${persona.toUpperCase()} mode.\n`;
      
      if (persona === 'work') {
        systemPrompt += 'Provide professional, concise, work-focused assistance.\n';
      } else if (persona === 'home') {
        systemPrompt += 'Be friendly and helpful with personal matters.\n';
      } else if (persona === 'hobbies') {
        systemPrompt += 'Be enthusiastic about recreational activities.\n';
      }
      
      if (documents.length > 0) {
        systemPrompt += `\nYou have access to the following uploaded documents: ${documentList.join(', ')}\n`;
        
        if (isDocumentQuery) {
          systemPrompt += `\nThe user appears to be asking about documents. Use the document content provided to give a detailed, accurate response.\n`;
        }
      } else {
        systemPrompt += `\nNo documents have been uploaded to the ${persona} persona yet.\n`;
      }
      
      // Combine everything
      const fullPrompt = systemPrompt + documentContext + `\nUser Query: "${transcript}"\n\nResponse:`;
      
      console.log(`📝 Prompt includes ${documents.length} documents, total length: ${fullPrompt.length} chars`);
      
      const message = await anthropic.messages.create({
        model: LLM_MODEL,
        max_tokens: 500, // Increased for document summaries
        messages: [{
          role: 'user',
          content: fullPrompt
        }]
      });

      const response = message.content[0].type === 'text' ? message.content[0].text : 'Unable to process';
      console.log(`✅ AI Response generated: ${response.substring(0, 100)}...`);
      
      return response;
    } catch (error) {
      console.error('❌ AI Error:', error);
      return 'Sorry, I encountered an error processing your request.';
    }
  }

  private paginateText(text: string, maxCharsPerPage: number = 150): string[] {
    const words = text.split(' ');
    const pages: string[] = [];
    let currentPage = '';
    let currentLength = 0;

    for (const word of words) {
      if (currentLength + word.length > maxCharsPerPage && currentPage.length > 0) {
        pages.push(currentPage.trim());
        currentPage = word;
        currentLength = word.length;
      } else {
        currentPage += (currentPage ? ' ' : '') + word;
        currentLength += word.length + 1;
      }
    }

    if (currentPage.trim()) {
      pages.push(currentPage.trim());
    }

    return pages.length > 0 ? pages : [text];
  }

  private displayPage(session: AppSession, pageText: string, duration: number, totalPages: number, pageNum: number) {
    const header = totalPages > 1 ? `[${pageNum + 1}/${totalPages}]\n` : '';
    session.layouts.showTextWall(header + pageText, {
      view: ViewType.MAIN,
      durationMs: duration,
    });
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

    console.log(`📨 Event: ${eventType}`);
  }

  public async start() {
    await super.start();
    
    console.log('\n' + '='.repeat(70));
    console.log('🚀 PHONEGPT COMPLETE SYSTEM STARTED');
    console.log('='.repeat(70));
    console.log(`📱 Port: ${PORT}`);
    console.log(`🔐 Database: phonegpt.db`);
    console.log(`🤖 AI Model: ${LLM_MODEL}`);
    console.log(`✨ Features: Glass Sessions • Personas • Documents • Teleprompter`);
    console.log('='.repeat(70));
    console.log('\n📍 API Endpoints:');
    console.log('   Auth: /api/auth/login, /api/auth/signup');
    console.log('   Glass: /api/glass-sessions (CRUD)');
    console.log('   Conversations: /api/glass-sessions/:id/conversations');
    console.log('   Documents: /api/documents (with personas)');
    console.log('   Chat: /api/sessions (web interface)');
    console.log('\n✅ Ready for connections!\n');
  }
}

// ============================================================================
// Server Initialization
// ============================================================================
const mentraOSApp = new PhoneGPTMentraOSApp();

mentraOSApp.start().catch((error) => {
  console.error('❌ Failed to start server:', error);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down gracefully...');
  db.close();
  process.exit(0);
});

export default mentraOSApp;