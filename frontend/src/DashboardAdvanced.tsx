import React, { useState, useEffect, useRef } from 'react';
import { Moon, Sun, BarChart3, Zap, AlertCircle, CheckCircle, Clock, Wifi, WifiOff } from 'lucide-react';
import axios from 'axios';

interface LogEntry {
  id: string;
  timestamp: string;
  level: 'info' | 'error' | 'warning' | 'success';
  message: string;
  service?: string;
}

interface SessionStats {
  activeSessions: number;
  totalRequests: number;
  errorRate: number;
  avgResponseTime: number;
  uptime: string;
  cpu?: number;
  memory?: number;
}

const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://phoneGPT-webhook.systemd.diskstation.me';
const WS_URL = import.meta.env.VITE_WS_URL || 'ws://phoneGPT-webhook.systemd.diskstation.me';

const DashboardAdvanced: React.FC = () => {
  const [darkMode, setDarkMode] = useState(false);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [stats, setStats] = useState<SessionStats>({
    activeSessions: 0,
    totalRequests: 0,
    errorRate: 0,
    avgResponseTime: 0,
    uptime: '99.9%',
    cpu: 0,
    memory: 0
  });
  const [selectedFilter, setSelectedFilter] = useState<'all' | 'error' | 'warning' | 'success'>('all');
  const [isConnected, setIsConnected] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const wsRef = useRef<WebSocket | null>(null);
  const refreshIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Initialize WebSocket connection
  useEffect(() => {
    const connectWebSocket = () => {
      try {
        wsRef.current = new WebSocket(`${WS_URL}/stats`);

        wsRef.current.onopen = () => {
          console.log('WebSocket connected');
          setIsConnected(true);
        };

        wsRef.current.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            setStats(prev => ({
              ...prev,
              ...data
            }));
          } catch (e) {
            console.error('Failed to parse WebSocket data:', e);
          }
        };

        wsRef.current.onerror = (error) => {
          console.error('WebSocket error:', error);
          setIsConnected(false);
        };

        wsRef.current.onclose = () => {
          console.log('WebSocket disconnected');
          setIsConnected(false);
          // Try to reconnect after 3 seconds
          setTimeout(connectWebSocket, 3000);
        };
      } catch (error) {
        console.error('WebSocket connection failed:', error);
        setIsConnected(false);
      }
    };

    connectWebSocket();

    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  // Fetch logs from API
  const fetchLogs = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/logs?limit=50`);
      setLogs(response.data || []);
    } catch (error) {
      console.error('Failed to fetch logs:', error);
      // Fallback to mock data
      setLogs([
        { id: '1', timestamp: new Date().toLocaleTimeString(), level: 'success', message: 'Connection established', service: 'WebSocket' },
        { id: '2', timestamp: new Date(Date.now() - 5000).toLocaleTimeString(), level: 'info', message: 'Request processed', service: 'API' },
      ]);
    }
  };

  useEffect(() => {
    // Fetch logs on mount
    fetchLogs();

    // Set up auto-refresh interval
    if (autoRefresh) {
      refreshIntervalRef.current = setInterval(fetchLogs, 2000);
    }

    return () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
      }
    };
  }, [autoRefresh]);

  const filteredLogs = selectedFilter === 'all'
    ? logs
    : logs.filter(log => log.level === selectedFilter);

  const getLevelColor = (level: string) => {
    const colors: Record<string, { bg: string; text: string; icon: React.ReactNode }> = {
      error: { bg: 'bg-red-50 dark:bg-red-900/20', text: 'text-red-600 dark:text-red-400', icon: <AlertCircle className="w-4 h-4" /> },
      warning: { bg: 'bg-yellow-50 dark:bg-yellow-900/20', text: 'text-yellow-600 dark:text-yellow-400', icon: <AlertCircle className="w-4 h-4" /> },
      success: { bg: 'bg-green-50 dark:bg-green-900/20', text: 'text-green-600 dark:text-green-400', icon: <CheckCircle className="w-4 h-4" /> },
      info: { bg: 'bg-blue-50 dark:bg-blue-900/20', text: 'text-blue-600 dark:text-blue-400', icon: <BarChart3 className="w-4 h-4" /> },
    };
    return colors[level] || colors.info;
  };

  return (
    <div className={`min-h-screen ${darkMode ? 'dark bg-gray-900' : 'bg-gray-50'}`}>
      {/* Header */}
      <header className={`${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'} border-b sticky top-0 z-10`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center flex-wrap gap-4">
            <div className="flex items-center gap-3">
              <Zap className={`w-6 h-6 ${darkMode ? 'text-blue-400' : 'text-blue-600'}`} />
              <div>
                <h1 className={`text-xl sm:text-2xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                  PhoneGPT Dashboard
                </h1>
                <p className={`text-xs ${darkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                  {isConnected ? (
                    <span className="flex items-center gap-1">
                      <Wifi className="w-3 h-3 text-green-500" /> Live
                    </span>
                  ) : (
                    <span className="flex items-center gap-1">
                      <WifiOff className="w-3 h-3 text-red-500" /> Offline
                    </span>
                  )}
                </p>
              </div>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setAutoRefresh(!autoRefresh)}
                className={`p-2 rounded-lg transition-colors ${
                  autoRefresh
                    ? darkMode
                      ? 'bg-blue-600 text-white'
                      : 'bg-blue-100 text-blue-600'
                    : darkMode
                    ? 'bg-gray-700 text-gray-300'
                    : 'bg-gray-100 text-gray-600'
                }`}
                title={autoRefresh ? 'Auto-refresh enabled' : 'Auto-refresh disabled'}
              >
                <Zap className="w-5 h-5" />
              </button>
              <button
                onClick={() => setDarkMode(!darkMode)}
                className={`p-2 rounded-lg transition-colors ${
                  darkMode
                    ? 'bg-gray-700 hover:bg-gray-600 text-yellow-400'
                    : 'bg-gray-100 hover:bg-gray-200 text-gray-800'
                }`}
              >
                {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        {/* Stats Grid - Responsive */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {/* Active Sessions */}
          <StatCard
            title="Active Sessions"
            value={stats.activeSessions.toString()}
            icon={<Zap className="w-4 h-4" />}
            trend="↑ 12%"
            color="blue"
            darkMode={darkMode}
          />

          {/* Total Requests */}
          <StatCard
            title="Total Requests"
            value={stats.totalRequests.toLocaleString()}
            icon={<BarChart3 className="w-4 h-4" />}
            trend="↑ 8%"
            color="green"
            darkMode={darkMode}
          />

          {/* Error Rate */}
          <StatCard
            title="Error Rate"
            value={`${stats.errorRate}%`}
            icon={<AlertCircle className="w-4 h-4" />}
            trend="↓ 0.5%"
            color="red"
            darkMode={darkMode}
          />

          {/* Avg Response */}
          <StatCard
            title="Avg Response"
            value={`${stats.avgResponseTime}ms`}
            icon={<Clock className="w-4 h-4" />}
            trend="↓ 45ms"
            color="purple"
            darkMode={darkMode}
          />
        </div>

        {/* System Stats */}
        {(stats.cpu !== undefined || stats.memory !== undefined) && (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
            {stats.cpu !== undefined && (
              <div className={`p-4 sm:p-6 rounded-lg border ${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
                <div className="flex items-center justify-between mb-3">
                  <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>CPU Usage</span>
                  <span className={`text-lg font-bold ${stats.cpu > 80 ? 'text-red-600' : 'text-blue-600'}`}>{stats.cpu}%</span>
                </div>
                <div className={`w-full h-2 rounded-full ${darkMode ? 'bg-gray-700' : 'bg-gray-200'}`}>
                  <div
                    className={`h-full rounded-full transition-all ${stats.cpu > 80 ? 'bg-red-600' : 'bg-blue-600'}`}
                    style={{ width: `${stats.cpu}%` }}
                  />
                </div>
              </div>
            )}
            {stats.memory !== undefined && (
              <div className={`p-4 sm:p-6 rounded-lg border ${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
                <div className="flex items-center justify-between mb-3">
                  <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>Memory Usage</span>
                  <span className={`text-lg font-bold ${stats.memory > 80 ? 'text-red-600' : 'text-green-600'}`}>{stats.memory}%</span>
                </div>
                <div className={`w-full h-2 rounded-full ${darkMode ? 'bg-gray-700' : 'bg-gray-200'}`}>
                  <div
                    className={`h-full rounded-full transition-all ${stats.memory > 80 ? 'bg-red-600' : 'bg-green-600'}`}
                    style={{ width: `${stats.memory}%` }}
                  />
                </div>
              </div>
            )}
          </div>
        )}

        {/* Logs Section */}
        <div className={`rounded-lg border ${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
          <div className="p-4 sm:p-6 border-b border-gray-700">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <h2 className={`text-lg sm:text-xl font-semibold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                Live Logs ({filteredLogs.length})
              </h2>
              <div className="flex flex-wrap gap-2">
                {(['all', 'error', 'warning', 'success'] as const).map((filter) => (
                  <button
                    key={filter}
                    onClick={() => setSelectedFilter(filter)}
                    className={`px-3 py-1 text-xs sm:text-sm rounded-full transition-colors capitalize ${
                      selectedFilter === filter
                        ? 'bg-blue-600 text-white'
                        : darkMode
                        ? 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                    }`}
                  >
                    {filter}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Logs List */}
          <div className="max-h-96 sm:max-h-[500px] overflow-y-auto">
            {filteredLogs.length === 0 ? (
              <div className={`p-6 text-center ${darkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                No logs found
              </div>
            ) : (
              filteredLogs.map((log) => {
                const colors = getLevelColor(log.level);
                return (
                  <div
                    key={log.id}
                    className={`p-4 sm:p-6 border-t ${darkMode ? 'border-gray-700' : 'border-gray-200'} ${colors.bg}`}
                  >
                    <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className={colors.text}>{colors.icon}</span>
                          <span className={`font-semibold text-sm sm:text-base capitalize ${colors.text}`}>
                            {log.level}
                          </span>
                          {log.service && (
                            <span className={`text-xs px-2 py-1 rounded ${darkMode ? 'bg-gray-700 text-gray-300' : 'bg-gray-200 text-gray-700'}`}>
                              {log.service}
                            </span>
                          )}
                        </div>
                        <p className={`text-sm sm:text-base break-words ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>
                          {log.message}
                        </p>
                      </div>
                      <span className={`text-xs ${darkMode ? 'text-gray-400' : 'text-gray-500'} whitespace-nowrap`}>
                        {log.timestamp}
                      </span>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </main>
    </div>
  );
};

interface StatCardProps {
  title: string;
  value: string;
  icon: React.ReactNode;
  trend: string;
  color: 'blue' | 'green' | 'red' | 'purple';
  darkMode: boolean;
}

const StatCard: React.FC<StatCardProps> = ({ title, value, icon, trend, color, darkMode }) => {
  const colorMap = {
    blue: darkMode ? 'text-blue-400' : 'text-blue-600',
    green: darkMode ? 'text-green-400' : 'text-green-600',
    red: darkMode ? 'text-red-400' : 'text-red-600',
    purple: darkMode ? 'text-purple-400' : 'text-purple-600',
  };

  const hoverColorMap = {
    blue: 'hover:border-blue-500',
    green: 'hover:border-green-500',
    red: 'hover:border-red-500',
    purple: 'hover:border-purple-500',
  };

  return (
    <div
      className={`p-4 sm:p-6 rounded-lg border ${
        darkMode
          ? `bg-gray-800 border-gray-700 ${hoverColorMap[color]}`
          : `bg-white border-gray-200 ${hoverColorMap[color]}`
      } transition-colors`}
    >
      <div className="flex items-center justify-between mb-2">
        <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>
          {title}
        </span>
        <span className={colorMap[color]}>{icon}</span>
      </div>
      <p className={`text-2xl sm:text-3xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
        {value}
      </p>
      <p className="text-xs sm:text-sm text-green-600 mt-1">{trend}</p>
    </div>
  );
};

export default DashboardAdvanced;
