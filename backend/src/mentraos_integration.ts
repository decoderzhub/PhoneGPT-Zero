// ============================================================================
// PhoneGPT MentraOS Integration Module
// ============================================================================
// Add this to your backend_index.ts or create as separate module

import axios from 'axios';

// ============================================================================
// MentraOS Configuration
// ============================================================================

const MENTRAOS_CONFIG = {
  apiKey: process.env.MENTRAOS_API_KEY,
  packageName: process.env.PACKAGE_NAME,
  apiBaseUrl: 'https://api.mentra.glass',
  version: 'v1'
};

interface MentraOSSession {
  deviceId: string;
  userId: number;
  sessionId: number;
  timestamp: string;
  deviceModel?: string;
  battery?: number;
  connected: boolean;
}

// ============================================================================
// MentraOS API Client
// ============================================================================

class MentraOSClient {
  private apiKey: string;
  private packageName: string;
  private baseUrl: string;
  private headers: Record<string, string>;

  constructor() {
    this.apiKey = MENTRAOS_CONFIG.apiKey;
    this.packageName = MENTRAOS_CONFIG.packageName;
    this.baseUrl = MENTRAOS_CONFIG.apiBaseUrl;
    this.headers = {
      'Authorization': `Bearer ${this.apiKey}`,
      'Content-Type': 'application/json',
      'X-Package-Name': this.packageName
    };
  }

  /**
   * Verify MentraOS device authentication
   */
  async verifyDevice(deviceId: string, deviceToken: string): Promise<boolean> {
    try {
      const response = await axios.post(
        `${this.baseUrl}/${MENTRAOS_CONFIG.version}/devices/verify`,
        { deviceId, deviceToken },
        { headers: this.headers }
      );
      return response.data.verified;
    } catch (error) {
      console.error('MentraOS device verification failed:', error);
      return false;
    }
  }

  /**
   * Register a new MentraOS device session
   */
  async registerDevice(
    deviceId: string,
    deviceModel: string,
    userId: number,
    sessionId: number
  ): Promise<MentraOSSession | null> {
    try {
      const response = await axios.post(
        `${this.baseUrl}/${MENTRAOS_CONFIG.version}/devices/register`,
        {
          deviceId,
          deviceModel,
          userId,
          sessionId,
          package: this.packageName
        },
        { headers: this.headers }
      );

      return {
        deviceId,
        userId,
        sessionId,
        timestamp: new Date().toISOString(),
        deviceModel,
        connected: true
      };
    } catch (error) {
      console.error('MentraOS device registration failed:', error);
      return null;
    }
  }

  /**
   * Sync user session to MentraOS glasses
   */
  async syncSession(
    deviceId: string,
    sessionId: number,
    messages: Array<{ role: string; content: string; timestamp: string }>
  ): Promise<boolean> {
    try {
      await axios.post(
        `${this.baseUrl}/${MENTRAOS_CONFIG.version}/sync/session`,
        {
          deviceId,
          sessionId,
          messages,
          package: this.packageName,
          timestamp: new Date().toISOString()
        },
        { headers: this.headers }
      );
      return true;
    } catch (error) {
      console.error('MentraOS session sync failed:', error);
      return false;
    }
  }

  /**
   * Push notification to MentraOS glasses
   */
  async pushNotification(
    deviceId: string,
    message: string,
    actionUrl?: string
  ): Promise<boolean> {
    try {
      await axios.post(
        `${this.baseUrl}/${MENTRAOS_CONFIG.version}/notifications/push`,
        {
          deviceId,
          message,
          actionUrl,
          package: this.packageName,
          priority: 'high'
        },
        { headers: this.headers }
      );
      return true;
    } catch (error) {
      console.error('MentraOS notification failed:', error);
      return false;
    }
  }

  /**
   * Get device status and battery
   */
  async getDeviceStatus(deviceId: string): Promise<{
    connected: boolean;
    battery: number;
    model?: string;
  } | null> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/${MENTRAOS_CONFIG.version}/devices/${deviceId}/status`,
        { headers: this.headers }
      );
      return response.data;
    } catch (error) {
      console.error('MentraOS status check failed:', error);
      return null;
    }
  }

  /**
   * Send real-time message to glasses
   */
  async sendMessage(
    deviceId: string,
    sessionId: number,
    message: string,
    role: 'user' | 'assistant'
  ): Promise<boolean> {
    try {
      await axios.post(
        `${this.baseUrl}/${MENTRAOS_CONFIG.version}/messages/send`,
        {
          deviceId,
          sessionId,
          message,
          role,
          package: this.packageName,
          timestamp: new Date().toISOString()
        },
        { headers: this.headers }
      );
      return true;
    } catch (error) {
      console.error('MentraOS message send failed:', error);
      return false;
    }
  }
}

// ============================================================================
// Integration with Existing Backend
// ============================================================================

/**
 * Add these endpoints to your Express backend (backend_index.ts)
 */

// POST /api/mentraos/device/register
// Registers a MentraOS device and creates session link
async function registerMentraOSDevice(req: any, res: any) {
  try {
    const { deviceId, deviceModel, deviceToken } = req.body;
    const userId = req.user?.userId;

    if (!deviceId || !userId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const mentraOS = new MentraOSClient();

    // Verify device with MentraOS
    const verified = await mentraOS.verifyDevice(deviceId, deviceToken);
    if (!verified) {
      return res.status(401).json({ error: 'Device verification failed' });
    }

    // Create new session in database
    const result = await db.run(
      'INSERT INTO chatSessions (userId, sessionName) VALUES (?, ?)',
      [userId, `MentraOS Glass - ${new Date().toLocaleDateString()}`]
    );

    // Register device with MentraOS
    const mentraSession = await mentraOS.registerDevice(
      deviceId,
      deviceModel,
      userId,
      result.lastID
    );

    if (!mentraSession) {
      return res.status(500).json({ error: 'Failed to register device' });
    }

    // Store device-session mapping
    await db.run(
      `INSERT INTO mentraosDevices (deviceId, userId, sessionId, deviceModel)
       VALUES (?, ?, ?, ?)`,
      [deviceId, userId, result.lastID, deviceModel]
    );

    res.status(201).json({
      message: 'Device registered successfully',
      sessionId: result.lastID,
      deviceId
    });
  } catch (error) {
    console.error('Device registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// POST /api/mentraos/message/send
// Sends message to both backend storage and MentraOS glasses
async function sendMessageToMentraOS(req: any, res: any) {
  try {
    const { deviceId, sessionId, content, role } = req.body;
    const userId = req.user?.userId;

    // Verify user owns this session
    const session = await db.get(
      'SELECT * FROM chatSessions WHERE id = ? AND userId = ?',
      [sessionId, userId]
    );

    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    // Save message to database
    const msgResult = await db.run(
      'INSERT INTO chatMessages (sessionId, role, content) VALUES (?, ?, ?)',
      [sessionId, role, content]
    );

    // Send to MentraOS glasses
    const mentraOS = new MentraOSClient();
    const sent = await mentraOS.sendMessage(deviceId, sessionId, content, role);

    if (!sent) {
      console.warn('Failed to send to MentraOS, but message saved');
    }

    res.status(201).json({
      message: 'Message sent',
      messageId: msgResult.lastID,
      sentToDevice: sent
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// GET /api/mentraos/device/:deviceId/status
// Check device status and battery
async function getMentraOSDeviceStatus(req: any, res: any) {
  try {
    const { deviceId } = req.params;
    const userId = req.user?.userId;

    // Verify user owns this device
    const device = await db.get(
      'SELECT * FROM mentraosDevices WHERE deviceId = ? AND userId = ?',
      [deviceId, userId]
    );

    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }

    const mentraOS = new MentraOSClient();
    const status = await mentraOS.getDeviceStatus(deviceId);

    res.json({ status });
  } catch (error) {
    console.error('Status check error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// ============================================================================
// Database Schema Addition
// ============================================================================

/**
 * Add this table to your database initialization (backend_index.ts)
 * 
 * CREATE TABLE IF NOT EXISTS mentraosDevices (
 *   id INTEGER PRIMARY KEY AUTOINCREMENT,
 *   deviceId TEXT UNIQUE NOT NULL,
 *   userId INTEGER NOT NULL,
 *   sessionId INTEGER NOT NULL,
 *   deviceModel TEXT,
 *   registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 *   last_sync TIMESTAMP,
 *   battery_level INTEGER,
 *   is_connected BOOLEAN DEFAULT TRUE,
 *   FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
 *   FOREIGN KEY (sessionId) REFERENCES chatSessions(id) ON DELETE CASCADE
 * );
 */

// ============================================================================
// WebSocket Integration for Real-time Sync
// ============================================================================

/**
 * Add this to your Express backend for WebSocket support
 */

import { Server as HTTPServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';

function setupMentraOSWebSocket(httpServer: HTTPServer) {
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: process.env.FRONTEND_URL,
      credentials: true
    }
  });

  io.on('connection', (socket) => {
    console.log(`Device connected: ${socket.id}`);

    // Device registers with WebSocket
    socket.on('register-device', async (data) => {
      const { deviceId, userId, sessionId } = data;
      
      // Join room for this device
      socket.join(`device-${deviceId}`);
      socket.join(`session-${sessionId}`);

      console.log(`Device ${deviceId} registered for session ${sessionId}`);
    });

    // Handle incoming message from device
    socket.on('message-from-device', async (data) => {
      const { deviceId, sessionId, content } = data;

      // Broadcast to web client
      io.to(`session-${sessionId}`).emit('message-received', {
        source: 'device',
        deviceId,
        content
      });
    });

    // Handle device disconnection
    socket.on('disconnect', () => {
      console.log(`Device disconnected: ${socket.id}`);
    });
  });

  return io;
}

// ============================================================================
// Usage Example
// ============================================================================

/**
 * Example: How to integrate into your existing backend
 * 
 * 1. Add MentraOS endpoints to backend_index.ts:
 * 
 *    app.post('/api/mentraos/device/register', authenticateToken, registerMentraOSDevice);
 *    app.post('/api/mentraos/message/send', authenticateToken, sendMessageToMentraOS);
 *    app.get('/api/mentraos/device/:deviceId/status', authenticateToken, getMentraOSDeviceStatus);
 * 
 * 2. Add the mentraosDevices table to database initialization
 * 
 * 3. Modify message endpoint to sync with MentraOS:
 * 
 *    app.post('/api/sessions/:sessionId/messages', authenticateToken, async (req, res) => {
 *      // ... existing code ...
 *      
 *      // After saving message, sync to device
 *      const device = await db.get(
 *        'SELECT deviceId FROM mentraosDevices WHERE sessionId = ?',
 *        [sessionId]
 *      );
 *      
 *      if (device) {
 *        const mentraOS = new MentraOSClient();
 *        await mentraOS.sendMessage(device.deviceId, sessionId, content, role);
 *      }
 *    });
 * 
 * 4. Setup WebSocket connection:
 * 
 *    import http from 'http';
 *    const httpServer = http.createServer(app);
 *    setupMentraOSWebSocket(httpServer);
 * 
 *    httpServer.listen(PORT);
 */

// ============================================================================
// Export for use in backend_index.ts
// ============================================================================

export {
  MentraOSClient,
  registerMentraOSDevice,
  sendMessageToMentraOS,
  getMentraOSDeviceStatus,
  setupMentraOSWebSocket,
  MentraOSSession
};
