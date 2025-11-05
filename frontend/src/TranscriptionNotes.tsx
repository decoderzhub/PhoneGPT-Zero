// TranscriptionNotes.tsx - Metro-modern design inspired by Even Realities
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  Mic,
  FileText,
  Brain,
  Clock,
  Calendar,
  ChevronLeft,
  MoreVertical,
  Sparkles,
  Trash2,
  Edit3,
  Volume2,
  PauseCircle,
  PlayCircle
} from 'lucide-react';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:8112';

interface TranscriptionNote {
  id: number;
  title: string;
  transcript: string;
  summary?: string;
  duration: number;
  created_at: string;
}

interface TranscriptionNotesProps {
  persona: string;
  darkMode: boolean;
  onBack?: () => void;
}

const TranscriptionNotes: React.FC<TranscriptionNotesProps> = ({ 
  persona, 
  darkMode,
  onBack 
}) => {
  const [notes, setNotes] = useState<TranscriptionNote[]>([]);
  const [selectedNote, setSelectedNote] = useState<TranscriptionNote | null>(null);
  const [activeTab, setActiveTab] = useState<'transcript' | 'summary'>('transcript');
  const [loading, setLoading] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [recognition, setRecognition] = useState<any>(null);
  const [currentTranscript, setCurrentTranscript] = useState('');

  const axiosConfig = {
    headers: { 
      Authorization: `Bearer ${localStorage.getItem('token')}` 
    }
  };

  // Fetch notes on mount or persona change
  useEffect(() => {
    fetchNotes();
  }, [persona]);

  // Setup speech recognition
  useEffect(() => {
    if (typeof window !== 'undefined' && 'webkitSpeechRecognition' in window) {
      const SpeechRecognition = (window as any).webkitSpeechRecognition;
      const recognitionInstance = new SpeechRecognition();
      recognitionInstance.continuous = true;
      recognitionInstance.interimResults = true;
      recognitionInstance.lang = 'en-US';

      recognitionInstance.onresult = (event: any) => {
        let finalTranscript = '';
        for (let i = 0; i < event.results.length; i++) {
          if (event.results[i].isFinal) {
            finalTranscript += event.results[i][0].transcript + ' ';
          }
        }
        if (finalTranscript) {
          setCurrentTranscript(prev => prev + finalTranscript);
        }
      };

      setRecognition(recognitionInstance);
    }
  }, []);

  // Timer for recording
  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isRecording) {
      interval = setInterval(() => {
        setRecordingTime(prev => prev + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isRecording]);

  const fetchNotes = async () => {
    try {
      const response = await axios.get(
        `${API_URL}/api/transcription-notes/${persona}`,
        axiosConfig
      );
      setNotes(response.data);
    } catch (error) {
      console.error('Failed to fetch notes:', error);
    }
  };

  const startRecording = () => {
    if (recognition) {
      setIsRecording(true);
      setRecordingTime(0);
      setCurrentTranscript('');
      recognition.start();
    }
  };

  const stopRecording = async () => {
    if (recognition) {
      recognition.stop();
      setIsRecording(false);
      
      // Save the transcript
      if (currentTranscript.trim()) {
        try {
          const response = await axios.post(
            `${API_URL}/api/transcription-notes`,
            {
              persona,
              title: `Recording ${new Date().toLocaleString()}`,
              transcript: currentTranscript,
              duration: recordingTime
            },
            axiosConfig
          );
          
          await fetchNotes();
          setCurrentTranscript('');
          setRecordingTime(0);
        } catch (error) {
          console.error('Failed to save transcript:', error);
        }
      }
    }
  };

  const generateSummary = async (noteId: number) => {
    setLoading(true);
    try {
      const response = await axios.post(
        `${API_URL}/api/transcription-notes/${noteId}/summarize`,
        {},
        axiosConfig
      );
      
      // Update the note with summary
      setNotes(prev => prev.map(note => 
        note.id === noteId 
          ? { ...note, summary: response.data.summary }
          : note
      ));
      
      if (selectedNote?.id === noteId) {
        setSelectedNote({ ...selectedNote, summary: response.data.summary });
      }
      
      setActiveTab('summary');
    } catch (error) {
      console.error('Failed to generate summary:', error);
    } finally {
      setLoading(false);
    }
  };

  const deleteNote = async (noteId: number) => {
    try {
      await axios.delete(
        `${API_URL}/api/transcription-notes/${noteId}`,
        axiosConfig
      );
      setNotes(prev => prev.filter(n => n.id !== noteId));
      if (selectedNote?.id === noteId) {
        setSelectedNote(null);
      }
    } catch (error) {
      console.error('Failed to delete note:', error);
    }
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const formatTimestamp = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Main grid view when no note is selected
  if (!selectedNote) {
    return (
      <div className={`h-full flex flex-col ${darkMode ? 'bg-gray-900 text-white' : 'bg-gray-50 text-gray-900'}`}>
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <button onClick={onBack} className="p-2">
            <ChevronLeft className="w-5 h-5" />
          </button>
          <h1 className="text-xl font-medium">Transcribe</h1>
          <button className="p-2">
            <MoreVertical className="w-5 h-5" />
          </button>
        </div>

        {/* Metro Grid Layout */}
        <div className="flex-1 p-4 overflow-y-auto">
          {/* Recording Control Card */}
          <div className={`mb-6 p-6 rounded-2xl ${
            darkMode ? 'bg-gray-800' : 'bg-white'
          } shadow-lg`}>
            <div className="flex flex-col items-center">
              {!isRecording ? (
                <>
                  <button
                    onClick={startRecording}
                    className="w-24 h-24 rounded-full bg-gradient-to-br from-red-500 to-pink-500 flex items-center justify-center mb-4 shadow-xl hover:scale-105 transition-transform"
                  >
                    <Mic className="w-10 h-10 text-white" />
                  </button>
                  <p className="text-sm opacity-70">Tap to Record</p>
                </>
              ) : (
                <>
                  <button
                    onClick={stopRecording}
                    className="w-24 h-24 rounded-full bg-gradient-to-br from-gray-600 to-gray-700 flex items-center justify-center mb-4 shadow-xl animate-pulse"
                  >
                    <PauseCircle className="w-10 h-10 text-white" />
                  </button>
                  <p className="text-2xl font-light mb-2">{formatDuration(recordingTime)}</p>
                  <p className="text-sm opacity-70">Recording...</p>
                  {currentTranscript && (
                    <div className="mt-4 p-3 rounded-lg bg-gray-100 dark:bg-gray-700 w-full">
                      <p className="text-sm">{currentTranscript}</p>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>

          {/* Notes List */}
          <div className="space-y-3">
            {notes.map((note) => (
              <button
                key={note.id}
                onClick={() => setSelectedNote(note)}
                className={`w-full p-4 rounded-xl text-left transition-all ${
                  darkMode 
                    ? 'bg-gray-800 hover:bg-gray-700' 
                    : 'bg-white hover:bg-gray-50'
                } shadow-md hover:shadow-lg`}
              >
                <div className="flex items-start justify-between mb-2">
                  <h3 className="font-medium text-lg">{note.title}</h3>
                  <span className="text-xs opacity-60">
                    {formatDuration(note.duration)}
                  </span>
                </div>
                <p className="text-sm opacity-70 line-clamp-2 mb-2">
                  {note.transcript}
                </p>
                <div className="flex items-center justify-between">
                  <span className="text-xs opacity-50">
                    {new Date(note.created_at).toLocaleDateString()}
                  </span>
                  {note.summary && (
                    <span className="text-xs px-2 py-1 rounded-full bg-purple-500/20 text-purple-400">
                      Summarized
                    </span>
                  )}
                </div>
              </button>
            ))}
          </div>

          {notes.length === 0 && (
            <div className="flex flex-col items-center justify-center h-64 opacity-50">
              <Mic className="w-12 h-12 mb-4" />
              <p>No recordings yet</p>
              <p className="text-sm">Tap the record button to start</p>
            </div>
          )}
        </div>
      </div>
    );
  }

  // Detail view when a note is selected
  return (
    <div className={`h-full flex flex-col ${darkMode ? 'bg-gray-900 text-white' : 'bg-gray-50 text-gray-900'}`}>
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
        <button onClick={() => setSelectedNote(null)} className="p-2">
          <ChevronLeft className="w-5 h-5" />
        </button>
        <h1 className="text-xl font-medium">Transcribe</h1>
        <button 
          onClick={() => deleteNote(selectedNote.id)}
          className="p-2 text-red-500"
        >
          <Trash2 className="w-5 h-5" />
        </button>
      </div>

      {/* Note Title Card */}
      <div className={`m-4 p-4 rounded-xl ${darkMode ? 'bg-gray-800' : 'bg-white'}`}>
        <h2 className="text-lg font-medium mb-2">{selectedNote.title}</h2>
        <div className="flex items-center gap-4 text-sm opacity-60">
          <span>{new Date(selectedNote.created_at).toLocaleString()}</span>
          <span>{formatDuration(selectedNote.duration)}</span>
        </div>
      </div>

      {/* Tab Switcher */}
      <div className="flex mx-4 mb-4 bg-gray-200 dark:bg-gray-800 rounded-xl p-1">
        <button
          onClick={() => setActiveTab('transcript')}
          className={`flex-1 py-2 px-4 rounded-lg transition-all ${
            activeTab === 'transcript'
              ? `${darkMode ? 'bg-gray-700' : 'bg-white'} shadow-md`
              : ''
          }`}
        >
          Transcript
        </button>
        <button
          onClick={() => setActiveTab('summary')}
          className={`flex-1 py-2 px-4 rounded-lg transition-all ${
            activeTab === 'summary'
              ? `${darkMode ? 'bg-gray-700' : 'bg-white'} shadow-md`
              : ''
          }`}
        >
          AI Summary
        </button>
      </div>

      {/* Content Area */}
      <div className="flex-1 overflow-y-auto px-4 pb-4">
        {activeTab === 'transcript' ? (
          <div className={`p-4 rounded-xl ${darkMode ? 'bg-gray-800' : 'bg-white'}`}>
            <div className="space-y-4">
              {selectedNote.transcript.split('\n').map((line, index) => (
                <div key={index} className="flex gap-3">
                  <span className="text-xs opacity-50 mt-1">
                    {formatTimestamp(index * 5)}
                  </span>
                  <p className="flex-1">{line}</p>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className={`p-4 rounded-xl ${darkMode ? 'bg-gray-800' : 'bg-white'}`}>
            {selectedNote.summary ? (
              <div className="prose prose-sm dark:prose-invert max-w-none">
                {selectedNote.summary.split('\n').map((line, index) => (
                  <p key={index} className="mb-2">{line}</p>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12">
                <button
                  onClick={() => generateSummary(selectedNote.id)}
                  disabled={loading}
                  className="px-6 py-3 rounded-xl bg-gradient-to-r from-purple-500 to-pink-500 text-white font-medium shadow-lg hover:shadow-xl transition-all disabled:opacity-50"
                >
                  {loading ? (
                    <span className="flex items-center gap-2">
                      <Sparkles className="w-5 h-5 animate-spin" />
                      Generating...
                    </span>
                  ) : (
                    <span className="flex items-center gap-2">
                      <Brain className="w-5 h-5" />
                      Tap to Summarize
                    </span>
                  )}
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default TranscriptionNotes;