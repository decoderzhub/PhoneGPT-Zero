import React, { useState } from 'react';
import { Eye, EyeOff, AlertCircle, CheckCircle, Lock, Mail } from 'lucide-react';
import axios from 'axios';

interface AuthPageProps {
  onAuthSuccess: (token: string, user: { id: number; email: string }) => void;
}

const AuthPage: React.FC<AuthPageProps> = ({ onAuthSuccess }) => {
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8112';

  interface PasswordRequirement {
    label: string;
    check: (pwd: string) => boolean;
  }

  const passwordRequirements: PasswordRequirement[] = [
    { label: 'At least 12 characters', check: (pwd) => pwd.length >= 12 },
    { label: 'Uppercase letter (A-Z)', check: (pwd) => /[A-Z]/.test(pwd) },
    { label: 'Lowercase letter (a-z)', check: (pwd) => /[a-z]/.test(pwd) },
    { label: 'Number (0-9)', check: (pwd) => /[0-9]/.test(pwd) },
    { label: 'Special character (!@#$%^&*)', check: (pwd) => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(pwd) },
  ];

  const passwordsMatch = password === confirmPassword;
  const allRequirementsMet = passwordRequirements.every(req => req.check(password));
  const isPasswordValid = isSignUp ? allRequirementsMet && passwordsMatch : true;

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!email || !password || !confirmPassword) {
      setError('Please fill in all fields');
      return;
    }

    if (!allRequirementsMet) {
      setError('Password does not meet all complexity requirements');
      return;
    }

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);

    try {
      const response = await axios.post(`${API_URL}/api/auth/signup`, {
        email,
        password,
      });

      onAuthSuccess(response.data.token, response.data.user);
    } catch (err: any) {
      const errorMessage = err.response?.data?.error || 'Signup failed. Please try again.';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!email || !password) {
      setError('Please fill in all fields');
      return;
    }

    setLoading(true);

    try {
      const response = await axios.post(`${API_URL}/api/auth/login`, {
        email,
        password,
      });

      onAuthSuccess(response.data.token, response.data.user);
    } catch (err: any) {
      const errorMessage = err.response?.data?.error || 'Login failed. Please try again.';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-600 to-blue-800 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Card */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          {/* Header */}
          <div className="text-center mb-8">
            <div className="flex items-center justify-center gap-2 mb-4">
              <Lock className="w-8 h-8 text-blue-600" />
              <h1 className="text-3xl font-bold text-gray-900">PhoneGPT</h1>
            </div>
            <p className="text-gray-600">
              {isSignUp ? 'Create your account' : 'Welcome back'}
            </p>
          </div>

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
              <p className="text-red-800 text-sm">{error}</p>
            </div>
          )}

          {/* Form */}
          <form onSubmit={isSignUp ? handleSignUp : handleLogin} className="space-y-4">
            {/* Email Input */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-600 focus:border-transparent outline-none transition"
                  disabled={loading}
                />
              </div>
            </div>

            {/* Password Input */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-600 focus:border-transparent outline-none transition"
                  disabled={loading}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-3 text-gray-400 hover:text-gray-600"
                  disabled={loading}
                >
                  {showPassword ? (
                    <EyeOff className="w-5 h-5" />
                  ) : (
                    <Eye className="w-5 h-5" />
                  )}
                </button>
              </div>
            </div>

            {/* Confirm Password (SignUp only) */}
            {isSignUp && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Confirm Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="••••••••••••"
                    className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-600 focus:border-transparent outline-none transition"
                    disabled={loading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3 top-3 text-gray-400 hover:text-gray-600"
                    disabled={loading}
                  >
                    {showConfirmPassword ? (
                      <EyeOff className="w-5 h-5" />
                    ) : (
                      <Eye className="w-5 h-5" />
                    )}
                  </button>
                </div>
                {password && confirmPassword && (
                  <div className="mt-2 flex items-center gap-2">
                    {passwordsMatch ? (
                      <>
                        <CheckCircle className="w-4 h-4 text-green-600" />
                        <span className="text-sm text-green-600">Passwords match</span>
                      </>
                    ) : (
                      <>
                        <AlertCircle className="w-4 h-4 text-red-600" />
                        <span className="text-sm text-red-600">Passwords don't match</span>
                      </>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Password Requirements (SignUp only) */}
            {isSignUp && (
              <div className="bg-gray-50 p-4 rounded-lg">
                <p className="text-sm font-medium text-gray-700 mb-3">
                  Password requirements:
                </p>
                <div className="space-y-2">
                  {passwordRequirements.map((req, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      {req.check(password) ? (
                        <CheckCircle className="w-4 h-4 text-green-600" />
                      ) : (
                        <div className="w-4 h-4 border-2 border-gray-300 rounded-full" />
                      )}
                      <span
                        className={`text-sm ${
                          req.check(password)
                            ? 'text-green-600 font-medium'
                            : 'text-gray-600'
                        }`}
                      >
                        {req.label}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading || (isSignUp && !isPasswordValid)}
              className={`w-full py-2 rounded-lg font-semibold transition-all duration-200 ${
                loading || (isSignUp && !isPasswordValid)
                  ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                  : 'bg-blue-600 text-white hover:bg-blue-700 active:scale-95'
              }`}
            >
              {loading ? (
                <span className="flex items-center justify-center gap-2">
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  {isSignUp ? 'Creating account...' : 'Signing in...'}
                </span>
              ) : isSignUp ? (
                'Create Account'
              ) : (
                'Sign In'
              )}
            </button>
          </form>

          {/* Toggle Auth Mode */}
          <div className="mt-6 text-center">
            <p className="text-gray-600 text-sm">
              {isSignUp ? 'Already have an account?' : "Don't have an account?"}{' '}
              <button
                onClick={() => {
                  setIsSignUp(!isSignUp);
                  setError('');
                  setPassword('');
                  setConfirmPassword('');
                }}
                className="text-blue-600 font-semibold hover:text-blue-700 transition-colors"
                disabled={loading}
              >
                {isSignUp ? 'Sign in' : 'Sign up'}
              </button>
            </p>
          </div>

          {/* Footer */}
          <div className="mt-6 pt-6 border-t border-gray-200 text-center">
            <p className="text-xs text-gray-500">
              Associated with MentraOS
            </p>
          </div>
        </div>

        {/* Privacy Notice */}
        <p className="text-white text-xs text-center mt-6 opacity-90">
          Your data is encrypted and stored securely. No personal data is sent to external services.
        </p>
      </div>
    </div>
  );
};

export default AuthPage;