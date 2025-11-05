// 🔗 Example Backend Integration for PhoneGPT Dashboard
// Add this to your Express/FastAPI backend

// ==================== EXAMPLE: Express.js ====================

const express = require('express');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Enable CORS for React dashboard
app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000'],
  credentials: true
}));

// Store connection state
const systemStats = {
  activeSessions: 0,
  totalRequests: 0,
  errorRate: 0,
  avgResponseTime: 0,
  cpu: 0,
  memory: 0,
  uptime: '99.9%'
};

const logs = [];

// ==================== 1. STATS API ENDPOINT ====================

app.get('/api/stats', (req, res) => {
  res.json(systemStats);
});

// ==================== 2. LOGS API ENDPOINT ====================

app.get('/api/logs', (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  const level = req.query.level || 'all';
  
  let filteredLogs = logs;
  if (level !== 'all') {
    filteredLogs = logs.filter(log => log.level === level);
  }
  
  res.json(filteredLogs.slice(-limit).reverse());
});

// ==================== 3. ADD LOG FUNCTION ====================

function addLog(message, level = 'info', service = 'Backend') {
  const log = {
    id: Date.now().toString(),
    timestamp: new Date().toLocaleTimeString(),
    level, // 'info', 'error', 'warning', 'success'
    message,
    service
  };
  
  logs.push(log);
  
  // Keep only last 200 logs
  if (logs.length > 200) {
    logs.shift();
  }
  
  // Broadcast to all WebSocket clients
  broadcastToClients({
    type: 'newLog',
    data: log
  });
  
  console.log(`[${level.toUpperCase()}] ${service}: ${message}`);
}

// ==================== 4. UPDATE STATS FUNCTION ====================

function updateStats(newStats) {
  Object.assign(systemStats, newStats);
  
  // Broadcast to all WebSocket clients
  broadcastToClients({
    type: 'statsUpdate',
    data: systemStats
  });
}

// ==================== 5. WEBSOCKET IMPLEMENTATION ====================

wss.on('connection', (ws) => {
  console.log('Dashboard client connected');
  addLog('Dashboard connected', 'success', 'WebSocket');
  
  // Send initial stats
  ws.send(JSON.stringify({
    type: 'init',
    data: systemStats
  }));
  
  // Broadcast stats every 2 seconds
  const statsInterval = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(systemStats));
    }
  }, 2000);
  
  ws.on('close', () => {
    clearInterval(statsInterval);
    console.log('Dashboard client disconnected');
    addLog('Dashboard disconnected', 'info', 'WebSocket');
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// ==================== 6. BROADCAST TO ALL CLIENTS ====================

function broadcastToClients(message) {
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(message));
    }
  });
}

// ==================== 7. EXAMPLE: UPDATE STATS FROM YOUR APP ====================

// Call this when processing requests
function handleRequest(serviceName, responseTime, success = true) {
  systemStats.totalRequests++;
  systemStats.activeSessions = Math.max(0, systemStats.activeSessions);
  
  if (!success) {
    systemStats.errorRate = (systemStats.errorRate + 0.1).toFixed(2);
    addLog(`Failed request in ${serviceName}`, 'error', serviceName);
  }
  
  systemStats.avgResponseTime = responseTime;
  
  updateStats(systemStats);
}

// ==================== 8. EXAMPLE: SESSION TRACKING ====================

const activeSessions = new Map();

function addSession(sessionId, metadata = {}) {
  activeSessions.set(sessionId, {
    createdAt: Date.now(),
    ...metadata
  });
  systemStats.activeSessions = activeSessions.size;
  updateStats(systemStats);
  addLog(`Session created: ${sessionId}`, 'success', 'SessionManager');
}

function removeSession(sessionId) {
  activeSessions.delete(sessionId);
  systemStats.activeSessions = activeSessions.size;
  updateStats(systemStats);
  addLog(`Session ended: ${sessionId}`, 'info', 'SessionManager');
}

// ==================== 9. EXAMPLE: SYSTEM MONITORING ====================

function startSystemMonitoring() {
  const os = require('os');
  
  setInterval(() => {
    // CPU Usage (simplified)
    const cpus = os.cpus();
    const load = os.loadavg()[0] / cpus.length * 100;
    systemStats.cpu = Math.min(100, load).toFixed(2);
    
    // Memory Usage
    const totalMemory = os.totalmem();
    const freeMemory = os.freemem();
    const usedMemory = totalMemory - freeMemory;
    systemStats.memory = ((usedMemory / totalMemory) * 100).toFixed(2);
    
    updateStats(systemStats);
  }, 5000);
}

// ==================== 10. INITIALIZE ====================

const PORT = 8112;

server.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`);
  console.log(`📊 Dashboard: http://localhost:5173`);
  console.log(`🔗 WebSocket: ws://localhost:${PORT}/stats`);
  
  // Start monitoring
  startSystemMonitoring();
  
  // Initial stats
  addLog('Server started', 'success', 'Backend');
  updateStats(systemStats);
});

// ==================== 11. USAGE EXAMPLES ====================

/*
// In your request handler:
app.get('/api/process', async (req, res) => {
  const startTime = Date.now();
  
  try {
    // Your business logic
    const result = await processData(req.body);
    
    const responseTime = Date.now() - startTime;
    handleRequest('DataProcessor', responseTime, true);
    
    res.json({ success: true, data: result });
  } catch (error) {
    handleRequest('DataProcessor', Date.now() - startTime, false);
    addLog(`Error: ${error.message}`, 'error', 'DataProcessor');
    res.status(500).json({ error: error.message });
  }
});

// Session management:
app.post('/api/login', (req, res) => {
  const sessionId = generateSessionId();
  addSession(sessionId, { userId: req.body.userId });
  res.json({ sessionId });
});

app.post('/api/logout', (req, res) => {
  removeSession(req.body.sessionId);
  res.json({ success: true });
});

// Manual logging:
addLog('PhoneGPT model loaded successfully', 'success', 'MLEngine');
addLog('High latency detected on database query', 'warning', 'Database');
addLog('Failed to connect to external API', 'error', 'ExternalAPI');
*/

// ==================== FastAPI EQUIVALENT ====================

/*
# FastAPI Example

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime
import asyncio
import psutil

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global state
stats = {
    "activeSessions": 0,
    "totalRequests": 0,
    "errorRate": 0,
    "avgResponseTime": 0,
    "cpu": 0,
    "memory": 0,
    "uptime": "99.9%"
}

logs = []

@app.get("/api/stats")
async def get_stats():
    return stats

@app.get("/api/logs")
async def get_logs(limit: int = 50, level: str = "all"):
    filtered = logs if level == "all" else [l for l in logs if l["level"] == level]
    return filtered[-limit:][::-1]

def add_log(message: str, level: str = "info", service: str = "Backend"):
    log = {
        "id": str(int(datetime.now().timestamp() * 1000)),
        "timestamp": datetime.now().strftime("%H:%M:%S"),
        "level": level,
        "message": message,
        "service": service
    }
    logs.append(log)
    if len(logs) > 200:
        logs.pop(0)

def update_stats(new_stats: dict):
    stats.update(new_stats)

# Example endpoint
@app.post("/api/process")
async def process_data(data: dict):
    stats["totalRequests"] += 1
    try:
        # Your logic here
        result = {"success": True}
        add_log("Data processed successfully", "success", "DataProcessor")
        return result
    except Exception as e:
        add_log(str(e), "error", "DataProcessor")
        return JSONResponse(status_code=500, content={"error": str(e)})

if __name__ == "__main__":
    import uvicorn
    add_log("Server started", "success", "Backend")
    uvicorn.run(app, host="0.0.0.0", port=8112)
*/
