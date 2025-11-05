// Updated PhoneGPTControl.tsx that works with both database sessions and glass sessions

import React, { useState, useEffect, useRef } from 'react';
import {
  Activity,
  Users,
  MessageSquare,
  Eye,
  Pause,
  Play,
  ChevronLeft,
  ChevronRight,
  Volume2,
  X,
  Menu,
  LogOut,
  ArrowLeft,
  Plus,
  Send,
  Glasses
} from 'lucide-react';
import axios from 'axios';

// Database chat session (from /api/sessions)
interface ChatSession {
  id: number;
  userId: number;
  sessionName: string;
  created_at: string;
  updated_at: string;
}

// MentraOS glass session (from /api/glass-sessions)
interface GlassSession {
  session_id: string;
  state: 'listening' | 'processing' | 'displaying' | 'paused';
  user_id: string;
  conversation_count: number;
  current_page: number;
  is_paused: boolean;
}

// Chat message
interface ChatMessage {
  id: number;
  sessionId: number;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

interface User {
  id: number;
  email: string;
}

interface PhoneGPTControlProps {
  user?: User;
  token?: string;
  onLogout?: () => void;
}

export default function PhoneGPTControl({ user, token, onLogout }: PhoneGPTControlProps) {
  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8112';
  
  // UI State
  const [darkMode, setDarkMode] = useState(false);
  const [activeTab, setActiveTab] = useState<'chat' | 'glasses'>('chat');
  
  // Chat State (Database)
  const [chatSessions, setChatSessions] = useState<ChatSession[]>([]);
  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(false);
  
  // Glass State (MentraOS)
  const [glassSessions, setGlassSessions] = useState<GlassSession[]>([]);
  const [selectedGlassId, setSelectedGlassId] = useState<string | null>(null);
  
  // Error state
  const [error, setError] = useState('');

  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  const axiosConfig = token ? {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  } : {};

  // Auto-scroll messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // ============================================================================
  // Chat Session Functions (Database)
  // ============================================================================

  const fetchChatSessions = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/sessions`, axiosConfig);
      setChatSessions(response.data || []);
      
      // Auto-select first session
      if (!selectedChatId && response.data.length > 0) {
        setSelectedChatId(response.data[0].id);
      }
    } catch (err: any) {
      console.error('Failed to fetch chat sessions:', err);
      setError('Failed to load sessions');
    }
  };

  const fetchMessages = async () => {
    if (!selectedChatId) return;
    
    try {
      const response = await axios.get(
        `${API_URL}/api/sessions/${selectedChatId}/messages`,
        axiosConfig
      );
      setMessages(response.data || []);
    } catch (err: any) {
      console.error('Failed to fetch messages:', err);
    }
  };

  const createChatSession = async () => {
    try {
      const response = await axios.post(
        `${API_URL}/api/sessions`,
        { sessionName: `Chat ${new Date().toLocaleString()}` },
        axiosConfig
      );
      
      await fetchChatSessions();
      setSelectedChatId(response.data.id);
    } catch (err: any) {
      console.error('Failed to create session:', err);
      setError('Failed to create new session');
    }
  };

  const sendMessage = async () => {
    if (!selectedChatId || !newMessage.trim()) return;
    
    setLoading(true);
    setError('');
    
    try {
      await axios.post(
        `${API_URL}/api/sessions/${selectedChatId}/messages`,
        { content: newMessage.trim() },
        axiosConfig
      );
      
      setNewMessage('');
      await fetchMessages();
    } catch (err: any) {
      console.error('Failed to send message:', err);
      setError('Failed to send message');
    } finally {
      setLoading(false);
    }
  };

  // ============================================================================
  // Glass Session Functions (MentraOS)
  // ============================================================================

  const fetchGlassSessions = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/glass-sessions`);
      setGlassSessions(response.data || []);
      
      if (!selectedGlassId && response.data.length > 0) {
        setSelectedGlassId(response.data[0].session_id);
      }
    } catch (err: any) {
      console.error('Failed to fetch glass sessions:', err);
    }
  };

  const pauseGlass = async () => {
    if (!selectedGlassId) return;
    
    try {
      await axios.post(`${API_URL}/api/glass-sessions/${selectedGlassId}/pause`);
      await fetchGlassSessions();
    } catch (err: any) {
      console.error('Failed to pause glass:', err);
    }
  };

  const resumeGlass = async () => {
    if (!selectedGlassId) return;
    
    try {
      await axios.post(`${API_URL}/api/glass-sessions/${selectedGlassId}/resume`);
      await fetchGlassSessions();
    } catch (err: any) {
      console.error('Failed to resume glass:', err);
    }
  };

  // ============================================================================
  // Lifecycle
  // ============================================================================

  useEffect(() => {
    if (activeTab === 'chat') {
      fetchChatSessions();
    } else {
      fetchGlassSessions();
    }
  }, [activeTab]);

  useEffect(() => {
    if (selectedChatId) {
      fetchMessages();
    }
  }, [selectedChatId]);

  // Polling for glass sessions
  useEffect(() => {
    if (activeTab === 'glasses') {
      const interval = setInterval(fetchGlassSessions, 2000);
      return () => clearInterval(interval);
    }
  }, [activeTab]);

  // ============================================================================
  // Render
  // ============================================================================

  return (
    <div className={`min-h-screen ${darkMode ? 'dark bg-gray-900' : 'bg-gray-50'}`}>
      {/* Header */}
      <header className={`${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'} border-b`}>
        <div className="max-w-7xl mx-auto px-4 py-3">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-3">
              <h1 className={`text-xl font-bold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                PhoneGPT Control
              </h1>
              {user && (
                <span className={`text-sm ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>
                  {user.email}
                </span>
              )}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setDarkMode(!darkMode)}
                className={`p-2 rounded-lg ${
                  darkMode ? 'bg-gray-700 text-yellow-400' : 'bg-gray-100 text-gray-800'
                }`}
              >
                {darkMode ? '☀️' : '🌙'}
              </button>
              {onLogout && (
                <button
                  onClick={onLogout}
                  className="p-2 rounded-lg bg-red-500 text-white hover:bg-red-600"
                >
                  <LogOut className="w-4 h-4" />
                </button>
              )}
            </div>
          </div>
        </div>
      </header>

      {/* Tab Switcher */}
      <div className="max-w-7xl mx-auto px-4 py-4">
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('chat')}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              activeTab === 'chat'
                ? 'bg-blue-500 text-white'
                : darkMode
                ? 'bg-gray-800 text-gray-300'
                : 'bg-white text-gray-700'
            }`}
          >
            <MessageSquare className="w-4 h-4 inline mr-2" />
            Chat Sessions
          </button>
          <button
            onClick={() => setActiveTab('glasses')}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              activeTab === 'glasses'
                ? 'bg-blue-500 text-white'
                : darkMode
                ? 'bg-gray-800 text-gray-300'
                : 'bg-white text-gray-700'
            }`}
          >
            <Glasses className="w-4 h-4 inline mr-2" />
            Glass Sessions
          </button>
        </div>
      </div>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 pb-8">
        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-800">{error}</p>
          </div>
        )}

        {/* Chat Tab */}
        {activeTab === 'chat' && (
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
            {/* Session List */}
            <div className={`lg:col-span-1 rounded-lg ${darkMode ? 'bg-gray-800' : 'bg-white'} p-4`}>
              <div className="flex justify-between items-center mb-4">
                <h2 className={`font-semibold ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                  Sessions
                </h2>
                <button
                  onClick={createChatSession}
                  className="p-1 rounded bg-blue-500 text-white hover:bg-blue-600"
                >
                  <Plus className="w-4 h-4" />
                </button>
              </div>
              <div className="space-y-2">
                {chatSessions.map((session) => (
                  <button
                    key={session.id}
                    onClick={() => setSelectedChatId(session.id)}
                    className={`w-full text-left p-2 rounded-lg transition-colors ${
                      selectedChatId === session.id
                        ? 'bg-blue-500 text-white'
                        : darkMode
                        ? 'hover:bg-gray-700 text-gray-300'
                        : 'hover:bg-gray-100 text-gray-700'
                    }`}
                  >
                    <div className="text-sm font-medium">{session.sessionName}</div>
                    <div className="text-xs opacity-70">
                      {new Date(session.updated_at).toLocaleString()}
                    </div>
                  </button>
                ))}
                {chatSessions.length === 0 && (
                  <p className={`text-center py-4 text-sm ${darkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                    No sessions yet. Create one!
                  </p>
                )}
              </div>
            </div>

            {/* Chat Area */}
            <div className={`lg:col-span-3 rounded-lg ${darkMode ? 'bg-gray-800' : 'bg-white'} p-4`}>
              {selectedChatId ? (
                <>
                  {/* Messages */}
                  <div className="h-96 overflow-y-auto mb-4 space-y-2">
                    {messages.map((msg) => (
                      <div
                        key={msg.id}
                        className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                      >
                        <div
                          className={`max-w-[70%] p-3 rounded-lg ${
                            msg.role === 'user'
                              ? 'bg-blue-500 text-white'
                              : darkMode
                              ? 'bg-gray-700 text-gray-300'
                              : 'bg-gray-100 text-gray-900'
                          }`}
                        >
                          <p className="whitespace-pre-wrap">{msg.content}</p>
                          <p className="text-xs mt-1 opacity-70">
                            {new Date(msg.timestamp).toLocaleTimeString()}
                          </p>
                        </div>
                      </div>
                    ))}
                    <div ref={messagesEndRef} />
                  </div>

                  {/* Input */}
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={newMessage}
                      onChange={(e) => setNewMessage(e.target.value)}
                      onKeyPress={(e) => e.key === 'Enter' && !loading && sendMessage()}
                      placeholder="Type a message..."
                      disabled={loading}
                      className={`flex-1 px-4 py-2 rounded-lg ${
                        darkMode
                          ? 'bg-gray-700 text-white placeholder-gray-400'
                          : 'bg-gray-100 text-gray-900 placeholder-gray-500'
                      }`}
                    />
                    <button
                      onClick={sendMessage}
                      disabled={loading || !newMessage.trim()}
                      className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                        loading || !newMessage.trim()
                          ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                          : 'bg-blue-500 text-white hover:bg-blue-600'
                      }`}
                    >
                      <Send className="w-4 h-4" />
                    </button>
                  </div>
                </>
              ) : (
                <div className="h-96 flex items-center justify-center">
                  <p className={`text-center ${darkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                    Select or create a session to start chatting
                  </p>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Glass Tab */}
        {activeTab === 'glasses' && (
          <div className={`rounded-lg ${darkMode ? 'bg-gray-800' : 'bg-white'} p-6`}>
            <h2 className={`text-xl font-semibold mb-4 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
              MentraOS Glass Sessions
            </h2>
            
            {glassSessions.length > 0 ? (
              <div className="space-y-4">
                {glassSessions.map((session) => (
                  <div
                    key={session.session_id}
                    className={`p-4 rounded-lg border ${
                      darkMode ? 'border-gray-700' : 'border-gray-200'
                    }`}
                  >
                    <div className="flex justify-between items-center">
                      <div>
                        <p className={`font-medium ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                          Session: {session.session_id.substring(0, 12)}...
                        </p>
                        <p className={`text-sm ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>
                          State: {session.state} | Conversations: {session.conversation_count}
                        </p>
                      </div>
                      <div className="flex gap-2">
                        {session.is_paused ? (
                          <button
                            onClick={() => {
                              setSelectedGlassId(session.session_id);
                              resumeGlass();
                            }}
                            className="px-3 py-1 rounded bg-green-500 text-white hover:bg-green-600"
                          >
                            <Play className="w-4 h-4" />
                          </button>
                        ) : (
                          <button
                            onClick={() => {
                              setSelectedGlassId(session.session_id);
                              pauseGlass();
                            }}
                            className="px-3 py-1 rounded bg-yellow-500 text-white hover:bg-yellow-600"
                          >
                            <Pause className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className={`text-center py-8 ${darkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                No active glass sessions. Connect your Even Realities glasses to start.
              </p>
            )}
          </div>
        )}
      </main>
    </div>
  );
}