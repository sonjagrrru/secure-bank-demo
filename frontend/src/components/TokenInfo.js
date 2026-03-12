import React, { useState, useEffect } from 'react';
import { parseToken } from '../api';

export default function TokenInfo() {
  const [rawVisible, setRawVisible] = useState(false);
  const [copied, setCopied] = useState(false);
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [now, setNow] = useState(Date.now());
  const info = token ? parseToken(token) : null;

  useEffect(() => {
    const id = setInterval(() => {
      setNow(Date.now());
      const current = localStorage.getItem('token');
      setToken(prev => prev !== current ? current : prev);
    }, 1000);
    return () => clearInterval(id);
  }, []);

  if (!token || !info) {
    return (
      <div className="page">
        <h2>🔑 JWT Token Info</h2>
        <div className="error-message">Nema tokena. Prijavite se prvo.</div>
      </div>
    );
  }

  const parts = token.split('.');
  let header = {};
  try { header = JSON.parse(atob(parts[0])); } catch {}
  let payload = {};
  try { payload = JSON.parse(atob(parts[1])); } catch {}

  const timeLeft = info.expires - now;
  const hoursLeft = Math.max(0, Math.floor(timeLeft / 3600000));
  const minutesLeft = Math.max(0, Math.floor((timeLeft % 3600000) / 60000));
  const secondsLeft = Math.max(0, Math.floor((timeLeft % 60000) / 1000));

  return (
    <div className="page">
      <h2>🔑 JWT Token Info</h2>
      <p className="page-subtitle">Detalji autentifikacionog tokena</p>

      <div className="grid-3">
        <div className="stat-card">
          <div className="stat-icon">⏱</div>
          <div className="stat-label">Preostalo vreme</div>
          <div className={`stat-value ${info.isExpired ? 'text-red' : 'text-green'}`}>
            {info.isExpired ? 'ISTEKAO' : `${hoursLeft}h ${minutesLeft}m ${secondsLeft}s`}
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">🔐</div>
          <div className="stat-label">Algoritam</div>
          <div className="stat-value">{header.alg || 'N/A'}</div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">👤</div>
          <div className="stat-label">Uloga</div>
          <div className="stat-value">{info.role?.toUpperCase()}</div>
        </div>
      </div>

      <div className="grid-2">
        <div className="info-card">
          <h3>📋 Header (dekodiran)</h3>
          <pre className="code-block">{JSON.stringify(header, null, 2)}</pre>
        </div>
        <div className="info-card">
          <h3>📋 Payload (dekodiran)</h3>
          <pre className="code-block">{JSON.stringify(payload, null, 2)}</pre>
        </div>
      </div>

      <div className="info-card">
        <h3>📊 Detalji tokena</h3>
        <table className="info-table">
          <tbody>
            <tr><td>User ID</td><td>{info.user_id}</td></tr>
            <tr><td>Uloga</td><td><span className={`badge badge-${info.role}`}>{info.role}</span></td></tr>
            <tr><td>Izdat (iat)</td><td>{info.issued.toLocaleString('sr-Latn')}</td></tr>
            <tr><td>Ističe (exp)</td><td>{info.expires.toLocaleString('sr-Latn')}</td></tr>
            <tr>
              <td>Status</td>
              <td>
                <span className={`badge badge-${info.isExpired ? 'failed' : 'success'}`}>
                  {info.isExpired ? '⚠ Istekao' : '✓ Aktivan'}
                </span>
              </td>
            </tr>
            <tr><td>Algoritam</td><td>{header.alg}</td></tr>
            <tr><td>Tip</td><td>{header.typ}</td></tr>
          </tbody>
        </table>
      </div>

      <div className="info-card">
        <div className="card-header">
          <h3>🔒 Raw JWT Token</h3>
          <button onClick={() => setRawVisible(!rawVisible)} className="btn-small">
            {rawVisible ? 'Sakrij' : 'Prikaži'}
          </button>
        </div>
        {rawVisible && (
          <div className="token-raw">
            <div className="token-part">
              <span className="token-label">Header:</span>
              <code className="token-segment header">{parts[0]}</code>
            </div>
            <div className="token-part">
              <span className="token-label">Payload:</span>
              <code className="token-segment payload">{parts[1]}</code>
            </div>
            <div className="token-part">
              <span className="token-label">Signature:</span>
              <code className="token-segment signature">{parts[2]}</code>
            </div>
            <div style={{marginTop:'12px', borderTop:'1px solid #333', paddingTop:'12px'}}>
              <div style={{display:'flex', alignItems:'center', gap:'8px', marginBottom:'8px'}}>
                <span className="token-label">Ceo token:</span>
                <button className="btn-small" onClick={() => { navigator.clipboard.writeText(token); setCopied(true); setTimeout(() => setCopied(false), 2000); }}>
                  {copied ? '✓ Kopirano!' : '📋 Kopiraj'}
                </button>
              </div>
              <code style={{wordBreak:'break-all', fontSize:'0.75rem', color:'#0f0', display:'block', background:'#111', padding:'8px', borderRadius:'4px', userSelect:'all'}}>{token}</code>
            </div>
          </div>
        )}
      </div>

      <div className="info-card">
        <h3>ℹ️ Kako JWT radi</h3>
        <div className="security-features">
          <div className="security-item">
            <span className="security-check">1</span>
            <span>Korisnik se prijavi sa email/lozinkom → backend verificira</span>
          </div>
          <div className="security-item">
            <span className="security-check">2</span>
            <span>Backend generiše JWT token potpisan sa SECRET_KEY (HS256)</span>
          </div>
          <div className="security-item">
            <span className="security-check">3</span>
            <span>Token se čuva u localStorage i šalje u svakom zahtevu</span>
          </div>
          <div className="security-item">
            <span className="security-check">4</span>
            <span>Backend verifikuje potpis i proverava expire vreme</span>
          </div>
          <div className="security-item">
            <span className="security-check">5</span>
            <span>Uloga (role) iz tokena određuje RBAC pristup endpointima</span>
          </div>
        </div>
      </div>
    </div>
  );
}
