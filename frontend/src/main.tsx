import React, { useState, useEffect } from 'react'
import ReactDOM from 'react-dom/client'
import AuthPage from './AuthPage'
import PhoneGPTControl from './PhoneGPTControl'
import './index.css'

interface AuthState {
  token: string | null;
  user: { id: number; email: string } | null;
}

const App: React.FC = () => {
  const [authState, setAuthState] = useState<AuthState>({
    token: null,
    user: null,
  });
  const [isLoading, setIsLoading] = useState(true);

  // Check for stored token on mount
  useEffect(() => {
    const storedToken = localStorage.getItem('auth_token');
    const storedUser = localStorage.getItem('auth_user');

    if (storedToken && storedUser) {
      try {
        const user = JSON.parse(storedUser);
        setAuthState({
          token: storedToken,
          user,
        });
      } catch (error) {
        console.error('Failed to parse stored auth state:', error);
        localStorage.removeItem('auth_token');
        localStorage.removeItem('auth_user');
      }
    }

    setIsLoading(false);
  }, []);

  const handleAuthSuccess = (token: string, user: { id: number; email: string }) => {
    // Store auth state
    localStorage.setItem('auth_token', token);
    localStorage.setItem('auth_user', JSON.stringify(user));

    // Update state
    setAuthState({
      token,
      user,
    });
  };

  const handleLogout = () => {
    // Clear stored auth state
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');

    // Reset state
    setAuthState({
      token: null,
      user: null,
    });
  };

  if (isLoading) {
    return (
      <div className="w-screen h-screen bg-gradient-to-br from-blue-600 to-blue-800 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-white border-t-transparent rounded-full animate-spin" />
          <p className="text-white font-semibold">Loading PhoneGPT...</p>
        </div>
      </div>
    );
  }

  return authState.token && authState.user ? (
    <PhoneGPTControl
      user={authState.user}
      token={authState.token}
      onLogout={handleLogout}
    />
  ) : (
    <AuthPage onAuthSuccess={handleAuthSuccess} />
  );
};

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);