import React, { useState, useEffect } from 'react';
import { Moon, Sun, BarChart3, Zap, AlertCircle, CheckCircle, Clock, Settings } from 'lucide-react';

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
}

const Dashboard: React.FC = () => {
  const [darkMode, setDarkMode] = useState(false);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [stats, setStats] = useState<SessionStats>({
    activeSessions: 0,
    totalRequests: 0,
    errorRate: 0,
    avgResponseTime: 0,
    uptime: '99.9%'
  });
  const [selectedFilter, setSelectedFilter] = useState<'all' | 'error' | 'warning' | 'success'>('all');

  // Simulate WebSocket connection
  useEffect(() => {
    const mockStats = {
      activeSessions: Math.floor(Math.random() * 100) + 20,
      totalRequests: Math.floor(Math.random() * 10000) + 5000,
      errorRate: (Math.random() * 5).toFixed(2),
      avgResponseTime: Math.floor(Math.random() * 500) + 50,
      uptime: '99.9%'
    };
    setStats(mockStats);

    // Simulate log entries
    const mockLogs: LogEntry[] = [
      { id: '1', timestamp: new Date().toLocaleTimeString(), level: 'success', message: 'Connection established', service: 'WebSocket' },
      { id: '2', timestamp: new Date(Date.now() - 5000).toLocaleTimeString(), level: 'info', message: 'Request processed', service: 'API' },
      { id: '3', timestamp: new Date(Date.now() - 10000).toLocaleTimeString(), level: 'warning', message: 'High latency detected', service: 'Network' },
      { id: '4', timestamp: new Date(Date.now() - 15000).toLocaleTimeString(), level: 'error', message: 'Failed to connect to database', service: 'Database' },
    ];
    setLogs(mockLogs);
  }, []);

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
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center gap-3">
            <Zap className={`w-6 h-6 ${darkMode ? 'text-blue-400' : 'text-blue-600'}`} />
            <h1 className={`text-xl sm:text-2xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
              PhoneGPT Dashboard
            </h1>
          </div>
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
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        {/* Stats Grid - Responsive */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {/* Active Sessions */}
          <div
            className={`p-4 sm:p-6 rounded-lg border ${
              darkMode
                ? 'bg-gray-800 border-gray-700 hover:border-blue-500'
                : 'bg-white border-gray-200 hover:border-blue-500'
            } transition-colors`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                Active Sessions
              </span>
              <Zap className={`w-4 h-4 ${darkMode ? 'text-blue-400' : 'text-blue-600'}`} />
            </div>
            <p className={`text-2xl sm:text-3xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
              {stats.activeSessions}
            </p>
            <p className="text-xs sm:text-sm text-green-600 mt-1">↑ 12% from last hour</p>
          </div>

          {/* Total Requests */}
          <div
            className={`p-4 sm:p-6 rounded-lg border ${
              darkMode
                ? 'bg-gray-800 border-gray-700 hover:border-green-500'
                : 'bg-white border-gray-200 hover:border-green-500'
            } transition-colors`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                Total Requests
              </span>
              <BarChart3 className={`w-4 h-4 ${darkMode ? 'text-green-400' : 'text-green-600'}`} />
            </div>
            <p className={`text-2xl sm:text-3xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
              {stats.totalRequests.toLocaleString()}
            </p>
            <p className="text-xs sm:text-sm text-green-600 mt-1">↑ 8% from yesterday</p>
          </div>

          {/* Error Rate */}
          <div
            className={`p-4 sm:p-6 rounded-lg border ${
              darkMode
                ? 'bg-gray-800 border-gray-700 hover:border-red-500'
                : 'bg-white border-gray-200 hover:border-red-500'
            } transition-colors`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                Error Rate
              </span>
              <AlertCircle className={`w-4 h-4 ${darkMode ? 'text-red-400' : 'text-red-600'}`} />
            </div>
            <p className={`text-2xl sm:text-3xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
              {stats.errorRate}%
            </p>
            <p className="text-xs sm:text-sm text-green-600 mt-1">↓ 0.5% improvement</p>
          </div>

          {/* Avg Response Time */}
          <div
            className={`p-4 sm:p-6 rounded-lg border ${
              darkMode
                ? 'bg-gray-800 border-gray-700 hover:border-purple-500'
                : 'bg-white border-gray-200 hover:border-purple-500'
            } transition-colors`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className={`text-sm font-medium ${darkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                Avg Response
              </span>
              <Clock className={`w-4 h-4 ${darkMode ? 'text-purple-400' : 'text-purple-600'}`} />
            </div>
            <p className={`text-2xl sm:text-3xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
              {stats.avgResponseTime}ms
            </p>
            <p className="text-xs sm:text-sm text-green-600 mt-1">↓ 45ms faster</p>
          </div>
        </div>

        {/* Logs Section */}
        <div className={`rounded-lg border ${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
          <div className="p-4 sm:p-6 border-b border-gray-700">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <h2 className={`text-lg sm:text-xl font-semibold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                Live Logs
              </h2>
              <div className="flex flex-wrap gap-2">
                {(['all', 'error', 'warning', 'success'] as const).map((filter) => (
                  <button
                    key={filter}
                    onClick={() => setSelectedFilter(filter)}
                    className={`px-3 py-1 text-xs sm:text-sm rounded-full transition-colors capitalize ${
                      selectedFilter === filter
                        ? darkMode
                          ? 'bg-blue-600 text-white'
                          : 'bg-blue-600 text-white'
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
                No logs found for this filter
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

export default Dashboard;
