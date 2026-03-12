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
        if (ms <= 0) { setTimeLeft('ISTEKAO'); return; }
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
      <p className="page-subtitle">Dobrodošli, {user.full_name}!</p>

      <div className="grid-3">
        <div className="stat-card">
          <div className="stat-icon">👤</div>
          <div className="stat-label">Uloga</div>
          <div className="stat-value">{user.role.toUpperCase()}</div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">🔗</div>
          <div className="stat-label">API Status</div>
          <div className={`stat-value ${health?.status === 'healthy' ? 'text-green' : 'text-red'}`}>
            {health ? (health.status === 'healthy' ? 'Povezan' : 'Greška') : 'Provera...'}
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">🔑</div>
          <div className="stat-label">Token ističe</div>
          <div className="stat-value">
            {tokenInfo ? timeLeft : '-'}
          </div>
        </div>
      </div>

      <div className="grid-2">
        <div className="info-card">
          <h3>Korisničke informacije</h3>
          <table className="info-table">
            <tbody>
              <tr><td>ID</td><td>{user.user_id}</td></tr>
              <tr><td>Email</td><td>{user.email || tokenInfo?.user_id}</td></tr>
              <tr><td>Ime</td><td>{user.full_name}</td></tr>
              <tr><td>Uloga</td><td><span className={`badge badge-${user.role}`}>{user.role}</span></td></tr>
            </tbody>
          </table>
        </div>

        <div className="info-card">
          <h3>Brze akcije</h3>
          <div className="quick-actions">
            <Link to="/accounts" className="action-btn">📋 Moji računi</Link>
            <Link to="/transfer" className="action-btn">💸 Novi transfer</Link>
            <Link to="/token-info" className="action-btn">🔑 Token detalji</Link>
            {user.role === 'admin' && (
              <Link to="/admin" className="action-btn">⚙️ Admin panel</Link>
            )}
          </div>
        </div>
      </div>

      <div className="info-card">
        <h3>🔐 Sigurnosne informacije</h3>
        <div className="security-features">
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>JWT autentifikacija sa {tokenInfo ? '24h' : '-'} istekom</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>AES-256 enkripcija salda i iznosa transakcija</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>bcrypt haširanje lozinki (salt rounds)</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>RBAC kontrola pristupa ({user.role})</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>Nginx reverse proxy sa SSL/TLS</span>
          </div>
          <div className="security-item">
            <span className="security-check">✓</span>
            <span>Rate limiting na API endpointima</span>
          </div>
        </div>
      </div>
    </div>
  );
}
