import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { api, parseToken } from '../api';

export default function Dashboard({ user }) {
  const [health, setHealth] = useState(null);
  const [tokenInfo, setTokenInfo] = useState(() => parseToken(localStorage.getItem('token')));
  const [timeLeft, setTimeLeft] = useState('');

  useEffect(() => {
    api.health().then(setHealth).catch(() => setHealth({ status: 'error' }));
  }, []);

  useEffect(() => {
    const tick = () => {
      const info = parseToken(localStorage.getItem('token'));
      setTokenInfo(info);
      if (info) {
        const ms = info.expires - Date.now();
        if (ms <= 0) { setTimeLeft('EXPIRED'); return; }
        const h = Math.floor(ms / 3600000);
        const m = Math.floor((ms % 3600000) / 60000);
        const s = Math.floor((ms % 60000) / 1000);
        setTimeLeft(`${h}h ${m}m ${s}s`);
      }
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="page">
      <h2>Dashboard</h2>
      <p className="page-subtitle">Welcome, {user.full_name}!</p>

      <div className="grid-3">
        <div className="stat-card">
          <div className="stat-icon">👤</div>
          <div className="stat-label">Role</div>
          <div className="stat-value">{user.role.toUpperCase()}</div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">🔗</div>
          <div className="stat-label">API Status</div>
          <div className={`stat-value ${health?.status === 'healthy' ? 'text-green' : 'text-red'}`}>
            {health ? (health.status === 'healthy' ? 'Connected' : 'Error') : 'Checking...'}
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">🔑</div>
          <div className="stat-label">Token Expires</div>
          <div className="stat-value">
            {tokenInfo ? timeLeft : '-'}
          </div>
        </div>
      </div>

      <div className="grid-2">
        <div className="info-card">
          <h3>User Information</h3>
          <table className="info-table">
            <tbody>
              <tr><td>ID</td><td>{user.user_id}</td></tr>
              <tr><td>Email</td><td>{user.email || tokenInfo?.user_id}</td></tr>
              <tr><td>Name</td><td>{user.full_name}</td></tr>
              <tr><td>Role</td><td><span className={`badge badge-${user.role}`}>{user.role}</span></td></tr>
            </tbody>
          </table>
        </div>

        <div className="info-card">
          <h3>Quick Actions</h3>
          <div className="quick-actions">
            <Link to="/accounts" className="action-btn">📋 My Accounts</Link>
            <Link to="/transfer" className="action-btn">💸 New Transfer</Link>
            <Link to="/token-info" className="action-btn">🔑 Token Details</Link>
            {user.role === 'admin' && (
              <Link to="/admin" className="action-btn">⚙️ Admin panel</Link>
            )}
          </div>
        </div>
      </div>

      <div className="info-card">
        <h3>🔐 Security Information</h3>
        <div className="security-features">
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>JWT authentication with {tokenInfo ? '24h' : '-'} expiry</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>AES-256 encryption of balances and transaction amounts</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>bcrypt password hashing (salt rounds)</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>RBAC access control ({user.role})</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>Nginx reverse proxy with SSL/TLS</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>Rate limiting on API endpoints</span>
          </div>
        </div>
      </div>
    </div>
  );
}
