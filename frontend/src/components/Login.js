import React, { useState } from 'react';
import { api } from '../api';

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showRegister, setShowRegister] = useState(false);

  // Register fields
  const [regEmail, setRegEmail] = useState('');
  const [regName, setRegName] = useState('');
  const [regPassword, setRegPassword] = useState('');
  const [regMessage, setRegMessage] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await api.login(email, password);
      localStorage.setItem('token', data.token);
      onLogin(data);
    } catch (err) {
      setError(err.error || 'Login error');
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setRegMessage('');
    setError('');
    try {
      await api.register(regEmail, regName, regPassword);
      setRegMessage('Registration successful! You can now log in.');
      setShowRegister(false);
      setEmail(regEmail);
    } catch (err) {
      setError(err.error || 'Registration error');
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h1>🏦 Banking App</h1>
        <p className="subtitle">Secure Banking System with Encryption</p>

        {error && <div className="error-message">{error}</div>}
        {regMessage && <div className="success-message">{regMessage}</div>}

        {!showRegister ? (
          <>
            <form onSubmit={handleLogin} className="form">
              <h2>Login</h2>
              <div className="form-group">
                <label>Email:</label>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@banking.local" required />
              </div>
              <div className="form-group">
                <label>Password:</label>
                <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                  placeholder="admin123" required />
              </div>
              <button type="submit" className="btn-primary" disabled={loading}>
                {loading ? 'Logging in...' : 'Log In'}
              </button>
            </form>
            <button className="btn-link" onClick={() => setShowRegister(true)}>
              Don't have an account? Register
            </button>
            <div className="test-users">
              <p className="small-text">Test users:</p>
              <ul>
                <li><strong>Admin:</strong> admin@banking.local</li>
                <li><strong>Teller:</strong> teller@banking.local</li>
                <li><strong>Customer:</strong> customer@banking.local</li>
                <li><strong>Password:</strong> admin123</li>
              </ul>
            </div>
          </>
        ) : (
          <>
            <form onSubmit={handleRegister} className="form">
              <h2>Register</h2>
              <div className="form-group">
                <label>Full Name:</label>
                <input type="text" value={regName} onChange={(e) => setRegName(e.target.value)}
                  placeholder="John Smith" required />
              </div>
              <div className="form-group">
                <label>Email:</label>
                <input type="email" value={regEmail} onChange={(e) => setRegEmail(e.target.value)}
                  placeholder="email@example.com" required />
              </div>
              <div className="form-group">
                <label>Password:</label>
                <input type="password" value={regPassword} onChange={(e) => setRegPassword(e.target.value)}
                  placeholder="Minimum 6 characters" required minLength={6} />
              </div>
              <button type="submit" className="btn-primary">Register</button>
            </form>
            <button className="btn-link" onClick={() => setShowRegister(false)}>
              Already have an account? Log in
            </button>
          </>
        )}

        <footer className="footer">
          <p>🔐 AES-256 encryption | bcrypt password hashing | JWT authentication</p>
        </footer>
      </div>
    </div>
  );
}
