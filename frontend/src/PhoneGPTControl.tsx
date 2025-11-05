import TranscriptionNotes from './TranscriptionNotes';
import React, { useState, useEffect, useRef } from 'react';
import {
  Glasses,
  Plus,
  Mic,
  MicOff,
  Play,
  Pause,
  ChevronRight,
  ChevronLeft,
  Upload,
  User,
  Briefcase,
  Home,
  Gamepad2,
  Settings,
  LogOut,
  Moon,
  Sun,
  Clock,
  X,
  FileText,
  Trash2,
  MessageCircle,
  Zap,
  Volume2,
  ArrowDown,
  Menu,
  ChevronDown,
  Navigation,
  ScrollText,
  Edit3,
  Languages,
  Brain,
  Activity
} from 'lucide-react';
import axios from 'axios';

// ============================================================================
// Type Definitions
// ============================================================================

interface User {
  id: number;
  email: string;
}

interface Persona {
  id: string;
  name: string;
  icon: React.ReactNode;
  color: string;
  documentCount: number;
}

interface GlassSession {
  id: number;
  userId: number;
  sessionName: string;
  deviceId?: string;
  created_at: string;
  updated_at: string;
  is_active: boolean;
  is_paused: boolean;
  wpm: number;
  persona: string;
}

interface GlassConversation {
  id: number;
  sessionId: number;
  query: string;
  response: string;
  timestamp: string;
  responsePages?: string[];
  currentPage?: number;
  duration?: number;
}

interface Document {
  id: number;
  fileName: string;
  content: string;
  persona: string;
  created_at: string;
}

// ============================================================================
// Main Component
// ============================================================================

export default function PhoneGPTControl({ user, token, onLogout }: {
  user?: User;
  token?: string;
  onLogout?: () => void;
}) {
  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8112';

  // UI State
  const [darkMode, setDarkMode] = useState(false);
  const [activePersona, setActivePersona] = useState('work');
  const [showConversationModal, setShowConversationModal] = useState(false);
  const [selectedConversation, setSelectedConversation] = useState<GlassConversation | null>(null);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [showSessions, setShowSessions] = useState(false);
  const [showDocuments, setShowDocuments] = useState(false);

  // Glass Session State
  const [glassSessions, setGlassSessions] = useState<GlassSession[]>([]);
  const [activeSessionId, setActiveSessionId] = useState<number | null>(null);
  const [conversations, setConversations] = useState<GlassConversation[]>([]);
  const [isListening, setIsListening] = useState(true);
  const [wpm, setWpm] = useState(180);
  const [currentDisplay, setCurrentDisplay] = useState<string>('');
  const [pageDisplayDuration, setPageDisplayDuration] = useState(5000); // Add this
  const [autoAdvancePages, setAutoAdvancePages] = useState(true); // Add this

  // Document State
  const [documents, setDocuments] = useState<Document[]>([]);
  const [uploadFile, setUploadFile] = useState<File | null>(null);

  // Modal page state
  const [modalCurrentPage, setModalCurrentPage] = useState(0);
  
  // Transcription Notes
  const [showTranscription, setShowTranscription] = useState(false);

  // Stats
  const [stats, setStats] = useState({
    totalConversations: 0,
    averageResponseTime: 0,
    activeGlassConnections: 0
  });

  const conversationEndRef = useRef<HTMLDivElement>(null);

  const axiosConfig = token ? {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  } : {};

  // ============================================================================
  // Personas Configuration
  // ============================================================================

  const personas: Persona[] = [
    { id: 'work', name: 'Work', icon: <Briefcase className="w-4 h-4" />, color: 'blue', documentCount: 0 },
    { id: 'home', name: 'Home', icon: <Home className="w-4 h-4" />, color: 'green', documentCount: 0 },
    { id: 'hobbies', name: 'Hobbies', icon: <Gamepad2 className="w-4 h-4" />, color: 'purple', documentCount: 0 }
  ];

  // ============================================================================
  // API Functions
  // ============================================================================

  const fetchGlassSessions = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/glass-sessions`, axiosConfig);
      setGlassSessions(response.data || []);
      
      // Auto-select active session if none selected
      if (!activeSessionId && response.data.length > 0) {
        const activeSessions = response.data.filter((s: GlassSession) => s.is_active);
        if (activeSessions.length > 0) {
          setActiveSessionId(activeSessions[0].id);
        }
      }
    } catch (error) {
      console.error('Failed to fetch glass sessions:', error);
    }
  };

  const createGlassSession = async () => {
    try {
      // First, mark current session as inactive if exists
      if (activeSessionId) {
        await axios.post(
          `${API_URL}/api/glass-sessions/${activeSessionId}/deactivate`,
          {},
          axiosConfig
        ).catch(() => {}); // Ignore error if endpoint doesn't exist
      }

      const response = await axios.post(
        `${API_URL}/api/glass-sessions`,
        { 
          sessionName: `Glass Session - ${new Date().toLocaleString()}`,
          persona: activePersona,
          wpm: wpm
        },
        axiosConfig
      );
      
      // Clear conversations for new session
      setConversations([]);
      
      // Set new session as active
      setActiveSessionId(response.data.id);
      
      // Refresh sessions list
      await fetchGlassSessions();
      
      // Close mobile menu if open
      setShowSessions(false);
    } catch (error) {
      console.error('Failed to create glass session:', error);
    }
  };

  const fetchConversations = async () => {
    if (!activeSessionId) return;
    
    try {
      const response = await axios.get(
        `${API_URL}/api/glass-sessions/${activeSessionId}/conversations`,
        axiosConfig
      );
      
      // Sort by timestamp DESC (newest first)
      const sorted = (response.data || []).sort((a: GlassConversation, b: GlassConversation) => 
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
      
      setConversations(sorted);
      
      // Calculate stats
      setStats({
        totalConversations: sorted.length,
        averageResponseTime: sorted.reduce((acc: number, c: GlassConversation) => 
          acc + (c.duration || 0), 0) / (sorted.length || 1),
        activeGlassConnections: glassSessions.filter(s => s.is_active).length
      });
    } catch (error) {
      console.error('Failed to fetch conversations:', error);
    }
  };

  const toggleListening = async () => {
    if (!activeSessionId) return;
    
    try {
      const endpoint = isListening ? 'pause' : 'resume';
      await axios.post(`${API_URL}/api/glass-sessions/${activeSessionId}/${endpoint}`, {}, axiosConfig);
      setIsListening(!isListening);
    } catch (error) {
      console.error('Failed to toggle listening:', error);
    }
  };

  const scrollToBottom = () => {
    conversationEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  };

  const updateWPM = async (newWpm: number) => {
    if (!activeSessionId) return;
    
    try {
      await axios.post(
        `${API_URL}/api/glass-sessions/${activeSessionId}/settings`,
        { wpm: newWpm },
        axiosConfig
      );
      setWpm(newWpm);
    } catch (error) {
      console.error('Failed to update WPM:', error);
    }
  };

  const uploadDocument = async () => {
    if (!uploadFile) return;
    
    const formData = new FormData();
    formData.append('file', uploadFile);
    formData.append('persona', activePersona);
    
    try {
      await axios.post(`${API_URL}/api/documents`, formData, {
        ...axiosConfig,
        headers: {
          ...axiosConfig.headers,
          'Content-Type': 'multipart/form-data'
        }
      });
      
      await fetchDocuments();
      setShowUploadModal(false);
      setUploadFile(null);
    } catch (error) {
      console.error('Failed to upload document:', error);
    }
  };

  const fetchDocuments = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/documents`, axiosConfig);
      setDocuments(response.data || []);
    } catch (error) {
      console.error('Failed to fetch documents:', error);
    }
  };

  const deleteGlassSession = async (sessionId: number) => {
    try {
      await axios.delete(`${API_URL}/api/glass-sessions/${sessionId}`, axiosConfig);
      
      if (activeSessionId === sessionId) {
        setActiveSessionId(null);
        setConversations([]);
      }
      
      await fetchGlassSessions();
    } catch (error) {
      console.error('Failed to delete session:', error);
    }
  };

  // ============================================================================
  // Effects
  // ============================================================================

  useEffect(() => {
    fetchGlassSessions();
    fetchDocuments();
  }, []);

  useEffect(() => {
    if (activeSessionId) {
      fetchConversations();
      const interval = setInterval(fetchConversations, 2000);
      return () => clearInterval(interval);
    }
  }, [activeSessionId]);

  // ============================================================================
  // Render
  // ============================================================================

  const activeSession = glassSessions.find(s => s.id === activeSessionId);

// Complete PhoneGPTControl return() with Metro Grid Integration
// Replace your entire return statement with this:

return (
  <div className={`min-h-screen ${darkMode ? 'bg-gray-900 text-white' : 'bg-gradient-to-br from-blue-50 to-purple-50'}`}>
    {/* ========== HEADER ========== */}
    <header className={`${darkMode ? 'bg-gray-800' : 'bg-white'} shadow-lg sticky top-0 z-40`}>
      <div className="px-4 py-3">
        <div className="flex justify-between items-center">
          {/* Logo and Title */}
          <div className="flex items-center gap-2">
            <Glasses className="w-6 h-6 text-blue-600" />
            <h1 className="text-lg sm:text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              PhoneGPT
            </h1>
          </div>
          
          {/* Desktop Actions */}
          <div className="hidden md:flex items-center gap-3">
            <div className="flex gap-1 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
              {personas.map(persona => (
                <button
                  key={persona.id}
                  onClick={() => setActivePersona(persona.id)}
                  className={`px-3 py-1.5 rounded-md flex items-center gap-2 transition-all ${
                    activePersona === persona.id
                      ? 'bg-blue-500 text-white'
                      : 'text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600'
                  }`}
                >
                  {persona.icon}
                  <span className="text-sm">{persona.name}</span>
                </button>
              ))}
            </div>

            <button
              onClick={() => setDarkMode(!darkMode)}
              className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            </button>

            {onLogout && (
              <button
                onClick={onLogout}
                className="px-3 py-1.5 rounded-lg bg-red-500 text-white hover:bg-red-600"
              >
                <LogOut className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <Menu className="w-5 h-5" />
          </button>
        </div>

        {/* Mobile Persona Selector */}
        <div className="md:hidden mt-3 flex gap-1 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
          {personas.map(persona => (
            <button
              key={persona.id}
              onClick={() => setActivePersona(persona.id)}
              className={`flex-1 px-2 py-1 rounded-md flex items-center justify-center gap-1 transition-all ${
                activePersona === persona.id
                  ? 'bg-blue-500 text-white'
                  : 'text-gray-600 dark:text-gray-400'
              }`}
            >
              {persona.icon}
              <span className="text-xs">{persona.name}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Mobile Menu Dropdown */}
      {mobileMenuOpen && (
        <div className={`md:hidden border-t ${darkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
          <div className="p-4 space-y-2">
            <button
              onClick={() => {
                setShowSettingsModal(true);
                setMobileMenuOpen(false);
              }}
              className="w-full text-left px-3 py-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              <Settings className="w-4 h-4 inline mr-2" />
              Settings
            </button>
            <button
              onClick={() => setDarkMode(!darkMode)}
              className="w-full text-left px-3 py-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              {darkMode ? <Sun className="w-4 h-4 inline mr-2" /> : <Moon className="w-4 h-4 inline mr-2" />}
              {darkMode ? 'Light Mode' : 'Dark Mode'}
            </button>
            {onLogout && (
              <button
                onClick={onLogout}
                className="w-full text-left px-3 py-2 rounded-lg text-red-600"
              >
                <LogOut className="w-4 h-4 inline mr-2" />
                Logout
              </button>
            )}
          </div>
        </div>
      )}
    </header>

    {/* ========== MAIN CONTENT ========== */}
    <div className="px-4 py-4">
      
      {/* ========== MOBILE VIEW WITH METRO GRID ========== */}
      <div className="md:hidden space-y-4">
        
        {/* METRO FEATURE GRID - Even Realities Style */}
        <div className="grid grid-cols-2 gap-3">
          {/* Transcribe Tile */}
          <button
            onClick={() => setShowTranscription(true)}
            className={`relative h-28 rounded-xl p-3 flex flex-col items-center justify-center transition-all active:scale-95 ${
              darkMode 
                ? 'bg-gradient-to-br from-purple-600 to-pink-600' 
                : 'bg-gradient-to-br from-purple-500 to-pink-500'
            } text-white shadow-lg`}
          >
            <Mic className="w-7 h-7 mb-1" />
            <span className="text-sm font-medium">Transcribe</span>
            <span className="text-xs opacity-80">Voice Notes</span>
          </button>

          {/* Glass Sessions Tile */}
          <button
            onClick={() => setShowSessions(!showSessions)}
            className={`relative h-28 rounded-xl p-3 flex flex-col items-center justify-center transition-all active:scale-95 ${
              darkMode 
                ? 'bg-gradient-to-br from-blue-600 to-cyan-600' 
                : 'bg-gradient-to-br from-blue-500 to-cyan-500'
            } text-white shadow-lg`}
          >
            <Glasses className="w-7 h-7 mb-1" />
            <span className="text-sm font-medium">Sessions</span>
            {glassSessions.length > 0 && (
              <span className="absolute top-2 right-2 bg-white text-blue-500 text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                {glassSessions.length}
              </span>
            )}
          </button>

          {/* Documents Tile */}
          <button
            onClick={() => setShowDocuments(!showDocuments)}
            className={`relative h-28 rounded-xl p-3 flex flex-col items-center justify-center transition-all active:scale-95 ${
              darkMode 
                ? 'bg-gradient-to-br from-green-600 to-emerald-600' 
                : 'bg-gradient-to-br from-green-500 to-emerald-500'
            } text-white shadow-lg`}
          >
            <FileText className="w-7 h-7 mb-1" />
            <span className="text-sm font-medium">Documents</span>
            {documents.filter(d => d.persona === activePersona).length > 0 && (
              <span className="absolute top-2 right-2 bg-white text-green-500 text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                {documents.filter(d => d.persona === activePersona).length}
              </span>
            )}
          </button>

          {/* Upload Tile */}
          <button
            onClick={() => setShowUploadModal(true)}
            className={`relative h-28 rounded-xl p-3 flex flex-col items-center justify-center transition-all active:scale-95 ${
              darkMode 
                ? 'bg-gradient-to-br from-orange-600 to-red-600' 
                : 'bg-gradient-to-br from-orange-500 to-red-500'
            } text-white shadow-lg`}
          >
            <Upload className="w-7 h-7 mb-1" />
            <span className="text-sm font-medium">Upload</span>
            <span className="text-xs opacity-80">Add Files</span>
          </button>
        </div>

        {/* Secondary Quick Actions Row */}
        <div className="grid grid-cols-4 gap-2">
          <button
            onClick={() => setShowSettingsModal(true)}
            className={`h-20 rounded-lg p-2 flex flex-col items-center justify-center transition-all active:scale-95 ${
              darkMode ? 'bg-gray-800' : 'bg-white'
            } shadow-md`}
          >
            <Settings className="w-5 h-5 mb-1 text-gray-500" />
            <span className="text-xs">Settings</span>
          </button>

          <button
            className={`h-20 rounded-lg p-2 flex flex-col items-center justify-center ${
              darkMode ? 'bg-gray-800' : 'bg-white'
            } shadow-md`}
          >
            <Volume2 className="w-5 h-5 mb-1 text-blue-500" />
            <span className="text-xs font-medium">{wpm}</span>
            <span className="text-xs opacity-60">WPM</span>
          </button>

          <button
            onClick={toggleListening}
            className={`h-20 rounded-lg p-2 flex flex-col items-center justify-center transition-all active:scale-95 ${
              darkMode ? 'bg-gray-800' : 'bg-white'
            } shadow-md`}
          >
            {isListening ? 
              <Mic className="w-5 h-5 mb-1 text-green-500 animate-pulse" /> : 
              <MicOff className="w-5 h-5 mb-1 text-red-500" />
            }
            <span className="text-xs font-medium">{isListening ? 'On' : 'Off'}</span>
          </button>

          <button
            className={`h-20 rounded-lg p-2 flex flex-col items-center justify-center ${
              darkMode ? 'bg-gray-800' : 'bg-white'
            } shadow-md opacity-50`}
            disabled
          >
            <Brain className="w-5 h-5 mb-1 text-purple-500" />
            <span className="text-xs">AI Chat</span>
          </button>
        </div>

        {/* Sessions Dropdown (triggered by tile) */}
        {showSessions && (
          <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg overflow-hidden`}>
            <div className="p-4">
              <button
                onClick={createGlassSession}
                className="w-full mb-3 p-2 rounded-lg bg-blue-500 text-white hover:bg-blue-600"
              >
                <Plus className="w-4 h-4 inline mr-2" />
                New Session
              </button>
              
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {glassSessions.map(session => (
                  <div
                    key={session.id}
                    onClick={() => {
                      setActiveSessionId(session.id);
                      setShowSessions(false);
                    }}
                    className={`p-3 rounded-lg cursor-pointer transition-all ${
                      activeSessionId === session.id
                        ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white'
                        : darkMode ? 'bg-gray-700' : 'bg-gray-50'
                    }`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="font-medium text-sm">{session.sessionName}</div>
                        <div className="text-xs opacity-70">{new Date(session.created_at).toLocaleDateString()}</div>
                        <div className="flex items-center gap-2 mt-1">
                          <span className={`text-xs px-2 py-0.5 rounded-full ${
                            session.persona === 'work' ? 'bg-blue-500/20 text-blue-400' :
                            session.persona === 'home' ? 'bg-green-500/20 text-green-400' :
                            'bg-purple-500/20 text-purple-400'
                          }`}>
                            {session.persona}
                          </span>
                          {session.is_active && (
                            <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                          )}
                        </div>
                      </div>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          deleteGlassSession(session.id);
                        }}
                        className="p-1 hover:bg-red-500 hover:text-white rounded"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Documents Dropdown (triggered by tile) */}
        {showDocuments && (
          <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg overflow-hidden`}>
            <div className="p-4">
              <button
                onClick={() => setShowUploadModal(true)}
                className="w-full mb-3 p-2 rounded-lg bg-purple-500 text-white"
              >
                <Plus className="w-4 h-4 inline mr-2" />
                Add Document
              </button>
              
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {documents
                  .filter(doc => doc.persona === activePersona)
                  .map(doc => (
                    <div
                      key={doc.id}
                      className="p-3 rounded-lg bg-gray-50 dark:bg-gray-700 flex items-center gap-2"
                    >
                      <FileText className="w-4 h-4 text-purple-500 flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <div className="text-sm font-medium truncate">{doc.fileName}</div>
                        <div className="text-xs text-gray-500">
                          {new Date(doc.created_at).toLocaleDateString()}
                        </div>
                      </div>
                      <button
                        onClick={async () => {
                          if (confirm(`Delete ${doc.fileName}?`)) {
                            try {
                              await axios.delete(
                                `${API_URL}/api/documents/${doc.id}`,
                                axiosConfig
                              );
                              await fetchDocuments();
                            } catch (error) {
                              console.error('Failed to delete document:', error);
                            }
                          }
                        }}
                        className="p-1.5 rounded hover:bg-red-500 hover:text-white transition-colors"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  ))}
                  
                {documents.filter(doc => doc.persona === activePersona).length === 0 && (
                  <p className="text-center text-gray-400 py-4 text-sm">No documents for {activePersona}</p>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Main Conversation Area */}
        <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg p-4`}>
          {activeSession ? (
            <>
              {/* Current Display */}
              {currentDisplay && (
                <div className="mb-4 p-4 bg-gradient-to-r from-blue-50 to-purple-50 dark:from-gray-700 dark:to-gray-600 rounded-lg">
                  <div className="text-base">{currentDisplay}</div>
                </div>
              )}

              {/* Conversation History */}
              <div className="relative">
                <div className="h-96 overflow-y-auto space-y-3">
                  {conversations.length === 0 ? (
                    <div className="text-center py-8 text-gray-400">
                      <MessageCircle className="w-12 h-12 mx-auto mb-2 opacity-50" />
                      <p>No conversations yet</p>
                      <p className="text-sm">Start speaking to see conversations here</p>
                    </div>
                  ) : (
                    conversations.map((conv) => (
                      <div
                        key={conv.id}
                        onClick={() => {
                          setSelectedConversation(conv);
                          setShowConversationModal(true);
                        }}
                        className="p-3 rounded-lg bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-700 dark:to-gray-600 cursor-pointer hover:shadow-md transition-all"
                      >
                        <div className="flex justify-between items-start mb-2">
                          <div className="flex items-start gap-2 flex-1">
                            <MessageCircle className="w-4 h-4 text-blue-500 mt-1 flex-shrink-0" />
                            <span className="text-sm font-medium">Q: {conv.query.substring(0, 50)}...</span>
                          </div>
                          <span className="text-xs text-gray-500 whitespace-nowrap ml-2">
                            {new Date(conv.timestamp).toLocaleTimeString()}
                          </span>
                        </div>
                        <div className="flex items-start gap-2">
                          <Zap className="w-4 h-4 text-purple-500 mt-1 flex-shrink-0" />
                          <span className="text-sm text-gray-600 dark:text-gray-300">
                            A: {conv.response.substring(0, 100)}...
                          </span>
                        </div>
                      </div>
                    ))
                  )}
                  <div ref={conversationEndRef} />
                </div>
              </div>

              {/* Statistics Dashboard */}
              <div className="mt-4 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <h3 className="font-semibold text-sm mb-2 flex items-center gap-2">
                  <Activity className="w-4 h-4 text-purple-500" />
                  Dashboard
                </h3>
                <div className="grid grid-cols-3 gap-2 text-xs">
                  <div className="text-center">
                    <p className="font-bold text-lg text-purple-500">{stats.totalConversations}</p>
                    <span className="text-gray-500">Conversations</span>
                  </div>
                  <div className="text-center">
                    <p className="font-bold text-lg text-blue-500">{stats.averageResponseTime.toFixed(1)}</p>
                    <span className="text-gray-500">Avg ms</span>
                  </div>
                  <div className="text-center">
                    <p className="font-bold text-lg text-green-500">{stats.activeGlassConnections}</p>
                    <span className="text-gray-500">Active</span>
                  </div>
                </div>
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center justify-center py-12 text-gray-400">
              <Glasses className="w-16 h-16 mb-4" />
              <p>Select or create a glass session to begin</p>
              <button
                onClick={createGlassSession}
                className="mt-4 px-4 py-2 rounded-lg bg-blue-500 text-white"
              >
                <Plus className="w-4 h-4 inline mr-2" />
                Create Session
              </button>
            </div>
          )}
        </div>
      </div>

      {/* ========== DESKTOP VIEW ========== */}
      <div className="hidden md:grid md:grid-cols-12 gap-6">
        {/* Left Sidebar - Sessions */}
        <div className="col-span-3">
          <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg p-4`}>
            <div className="flex justify-between items-center mb-4">
              <h2 className="font-semibold text-lg">Glass Sessions</h2>
              <button
                onClick={createGlassSession}
                className="p-2 rounded-lg bg-blue-500 text-white hover:bg-blue-600"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-2 max-h-96 overflow-y-auto">
              {glassSessions.map(session => (
                <div
                  key={session.id}
                  onClick={() => setActiveSessionId(session.id)}
                  className={`p-3 rounded-lg cursor-pointer transition-all ${
                    activeSessionId === session.id
                      ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white'
                      : darkMode ? 'bg-gray-700 hover:bg-gray-600' : 'bg-gray-50 hover:bg-gray-100'
                  }`}
                >
                  <div className="flex justify-between items-start">
                    <div>
                      <div className="font-medium text-sm">{session.sessionName}</div>
                      <div className="text-xs opacity-70">{new Date(session.created_at).toLocaleDateString()}</div>
                      <div className="flex items-center gap-2 mt-1">
                        <span className={`text-xs px-2 py-0.5 rounded-full ${
                          session.persona === 'work' ? 'bg-blue-500/20 text-blue-400' :
                          session.persona === 'home' ? 'bg-green-500/20 text-green-400' :
                          'bg-purple-500/20 text-purple-400'
                        }`}>
                          {session.persona}
                        </span>
                        {session.is_active && (
                          <>
                            <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                            <span className="text-xs">Active</span>
                          </>
                        )}
                      </div>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteGlassSession(session.id);
                      }}
                      className="p-1 hover:bg-red-500 hover:text-white rounded"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Desktop Transcribe Button */}
          <button
            onClick={() => setShowTranscription(true)}
            className="w-full mt-4 p-4 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 text-white shadow-lg hover:shadow-xl transition-all flex items-center justify-center gap-2"
          >
            <Mic className="w-5 h-5" />
            <span className="font-medium">Transcribe</span>
          </button>

          {/* Stats Widget */}
          <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg p-4 mt-4`}>
            <h3 className="font-semibold mb-3">Statistics</h3>
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Conversations</span>
                <span className="font-medium">{stats.totalConversations}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Avg Response Time</span>
                <span className="font-medium">{stats.averageResponseTime.toFixed(1)}ms</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-500">Active Glasses</span>
                <span className="font-medium">{stats.activeGlassConnections}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="col-span-6">
          <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg p-6 h-[calc(100vh-200px)]`}>
            {activeSession ? (
              <>
                {/* Controls */}
                <div className="flex justify-between items-center mb-4">
                  <div className="flex items-center gap-3">
                    <button
                      onClick={toggleListening}
                      className={`px-4 py-2 rounded-lg flex items-center gap-2 transition-all ${
                        isListening 
                          ? 'bg-green-500 text-white hover:bg-green-600'
                          : 'bg-red-500 text-white hover:bg-red-600'
                      }`}
                    >
                      {isListening ? <Mic className="w-4 h-4" /> : <MicOff className="w-4 h-4" />}
                      {isListening ? 'Listening' : 'Muted'}
                    </button>

                    <div className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 dark:bg-gray-700 rounded-lg">
                      <Volume2 className="w-4 h-4" />
                      <span className="text-sm">{wpm} WPM</span>
                    </div>
                  </div>

                  <button
                    onClick={() => setShowUploadModal(true)}
                    className="px-3 py-1.5 rounded-lg bg-purple-500 text-white hover:bg-purple-600 flex items-center gap-2"
                  >
                    <Upload className="w-4 h-4" />
                    Upload Doc
                  </button>
                </div>

                {/* Current Display */}
                {currentDisplay && (
                  <div className="mb-4 p-4 bg-gradient-to-r from-blue-50 to-purple-50 dark:from-gray-700 dark:to-gray-600 rounded-lg">
                    <div className="text-lg font-medium">{currentDisplay}</div>
                  </div>
                )}

                {/* Conversation History */}
                <div className="relative">
                  <div className="overflow-y-auto h-[calc(100%-120px)] space-y-3">
                    {conversations.map((conv) => (
                      <div
                        key={conv.id}
                        onClick={() => {
                          setSelectedConversation(conv);
                          setShowConversationModal(true);
                        }}
                        className="p-4 rounded-lg bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-700 dark:to-gray-600 cursor-pointer hover:shadow-md transition-all"
                      >
                        <div className="flex justify-between items-start mb-2">
                          <div className="flex items-center gap-2">
                            <MessageCircle className="w-4 h-4 text-blue-500" />
                            <span className="text-sm font-medium">Q: {conv.query.substring(0, 50)}...</span>
                          </div>
                          <span className="text-xs text-gray-500">
                            {new Date(conv.timestamp).toLocaleTimeString()}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Zap className="w-4 h-4 text-purple-500" />
                          <span className="text-sm text-gray-600 dark:text-gray-300">
                            A: {conv.response.substring(0, 100)}...
                          </span>
                        </div>
                      </div>
                    ))}
                    <div ref={conversationEndRef} />
                  </div>
                </div>
              </>
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-gray-400">
                <Glasses className="w-16 h-16 mb-4" />
                <p>Select or create a glass session to begin</p>
              </div>
            )}
          </div>
        </div>

        {/* Right Sidebar - Documents */}
        <div className="col-span-3">
          <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl shadow-lg p-4`}>
            <div className="flex justify-between items-center mb-4">
              <h2 className="font-semibold text-lg">Documents</h2>
              <button
                onClick={() => setShowUploadModal(true)}
                className="p-2 rounded-lg bg-purple-500 text-white hover:bg-purple-600"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-2">
              {documents
                .filter(doc => doc.persona === activePersona)
                .map(doc => (
                  <div
                    key={doc.id}
                    className="p-3 rounded-lg bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 flex items-center gap-2"
                  >
                    <FileText className="w-4 h-4 text-purple-500 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium truncate">{doc.fileName}</div>
                      <div className="text-xs text-gray-500">
                        {new Date(doc.created_at).toLocaleDateString()}
                      </div>
                    </div>
                    <button
                      onClick={async () => {
                        if (confirm(`Delete ${doc.fileName}?`)) {
                          try {
                            await axios.delete(
                              `${API_URL}/api/documents/${doc.id}`,
                              axiosConfig
                            );
                            await fetchDocuments();
                          } catch (error) {
                            console.error('Failed to delete document:', error);
                          }
                        }
                      }}
                      className="p-1.5 rounded hover:bg-red-500 hover:text-white transition-colors"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}
                
              {documents.filter(doc => doc.persona === activePersona).length === 0 && (
                <p className="text-center text-gray-400 py-4">No documents for {activePersona}</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>

    {/* ========== MODALS ========== */}
    
    {/* Transcription Notes Modal */}
    {showTranscription && (
      <div className="fixed inset-0 z-50 bg-black/50">
        <div className={`absolute inset-0 md:inset-8 rounded-2xl overflow-hidden ${
          darkMode ? 'bg-gray-900' : 'bg-gray-50'
        }`}>
          <TranscriptionNotes
            persona={activePersona}
            darkMode={darkMode}
            onBack={() => setShowTranscription(false)}
          />
        </div>
      </div>
    )}

    {/* Conversation Modal */}
    {showConversationModal && selectedConversation && (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
        <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl p-6 max-w-2xl w-full max-h-[80vh] overflow-y-auto`}>
          <div className="flex justify-between items-start mb-4">
            <h3 className="text-xl font-semibold">Conversation Details</h3>
            <button
              onClick={() => setShowConversationModal(false)}
              className="p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          
          <div className="space-y-4">
            <div>
              <h4 className="font-medium text-blue-500 mb-2">Question:</h4>
              <p className="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg">{selectedConversation.query}</p>
            </div>
            
            <div>
              <h4 className="font-medium text-purple-500 mb-2">Response:</h4>
              <p className="p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg whitespace-pre-wrap">
                {selectedConversation.response}
              </p>
            </div>
            
            <div className="text-sm text-gray-500">
              <Clock className="w-4 h-4 inline mr-1" />
              {new Date(selectedConversation.timestamp).toLocaleString()}
            </div>
          </div>
        </div>
      </div>
    )}

    {/* Upload Modal */}
    {showUploadModal && (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
        <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl p-6 max-w-md w-full`}>
          <div className="flex justify-between items-start mb-4">
            <h3 className="text-xl font-semibold">Upload Document</h3>
            <button
              onClick={() => setShowUploadModal(false)}
              className="p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Persona</label>
              <select
                value={activePersona}
                onChange={(e) => setActivePersona(e.target.value)}
                className="w-full p-2 rounded-lg border dark:bg-gray-700 dark:border-gray-600"
              >
                {personas.map(p => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">File</label>
              <input
                type="file"
                onChange={(e) => setUploadFile(e.target.files?.[0] || null)}
                className="w-full p-2 rounded-lg border dark:bg-gray-700 dark:border-gray-600"
              />
            </div>
            
            <button
              onClick={uploadDocument}
              disabled={!uploadFile}
              className="w-full py-2 rounded-lg bg-purple-500 text-white hover:bg-purple-600 disabled:opacity-50"
            >
              Upload
            </button>
          </div>
        </div>
      </div>
    )}

    {/* Settings Modal */}
    {showSettingsModal && (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
        <div className={`${darkMode ? 'bg-gray-800' : 'bg-white'} rounded-xl p-6 max-w-md w-full`}>
          <div className="flex justify-between items-start mb-4">
            <h3 className="text-xl font-semibold">Settings</h3>
            <button
              onClick={() => setShowSettingsModal(false)}
              className="p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Words Per Minute (WPM)</label>
              <input
                type="range"
                min="60"
                max="300"
                value={wpm}
                onChange={(e) => updateWPM(parseInt(e.target.value))}
                className="w-full"
              />
              <div className="flex justify-between text-sm text-gray-500">
                <span>60</span>
                <span className="font-medium">{wpm} WPM</span>
                <span>300</span>
              </div>
            </div>
            
            <div>
              <label className="block text-sm font-medium mb-2">Page Display Duration (Glasses)</label>
              <select 
                value={pageDisplayDuration}
                onChange={async (e) => {
                  const duration = parseInt(e.target.value);
                  setPageDisplayDuration(duration);
                  if (activeSessionId) {
                    try {
                      await axios.post(
                        `${API_URL}/api/glass-sessions/${activeSessionId}/page-settings`,
                        { pageDisplayDuration: duration },
                        axiosConfig
                      );
                    } catch (error) {
                      console.error('Failed to update page duration:', error);
                    }
                  }
                }}
                className="w-full p-2 rounded-lg border dark:bg-gray-700 dark:border-gray-600"
              >
                <option value="3000">3 seconds per page</option>
                <option value="5000">5 seconds per page</option>
                <option value="7000">7 seconds per page</option>
                <option value="10000">10 seconds per page</option>
                <option value="15000">15 seconds per page</option>
              </select>
            </div>
            
            <div>
              <label className="block text-sm font-medium mb-2">Auto-Advance Pages</label>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={autoAdvancePages}
                  onChange={async (e) => {
                    const enabled = e.target.checked;
                    setAutoAdvancePages(enabled);
                    if (activeSessionId) {
                      try {
                        await axios.post(
                          `${API_URL}/api/glass-sessions/${activeSessionId}/page-settings`,
                          { autoAdvance: enabled },
                          axiosConfig
                        );
                      } catch (error) {
                        console.error('Failed to update auto-advance:', error);
                      }
                    }
                  }}
                  className="w-4 h-4 rounded"
                />
                <span className="text-sm">Automatically cycle through response pages</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    )}
  </div>
);
}