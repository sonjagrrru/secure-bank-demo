import React, { useState } from 'react';
import { api } from '../api';

export default function Transfer() {
  const [fromId, setFromId] = useState('');
  const [toId, setToId] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleTransfer = async (e) => {
    e.preventDefault();
    setError('');
    setResult(null);
    setLoading(true);
    try {
      const data = await api.transfer(
        parseInt(fromId),
        parseInt(toId),
        parseFloat(amount),
        description || 'Transfer'
      );
      setResult(data);
    } catch (err) {
      setError(err.error || 'Transfer error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page">
      <h2>💸 Money Transfer</h2>
      <p className="page-subtitle">Transfer money between accounts</p>

      <div className="grid-2">
        <div className="info-card">
          <h3>New Transaction</h3>

          {error && <div className="error-message">{error}</div>}

          <form onSubmit={handleTransfer} className="form">
            <div className="form-group">
              <label>From Account (ID):</label>
              <input type="number" value={fromId} onChange={(e) => setFromId(e.target.value)}
                placeholder="Source account ID" required />
            </div>
            <div className="form-group">
              <label>To Account (ID):</label>
              <input type="number" value={toId} onChange={(e) => setToId(e.target.value)}
                placeholder="Destination account ID" required />
            </div>
            <div className="form-group">
              <label>Amount (RSD):</label>
              <input type="number" min="0.01" step="0.01" value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="1000.00" required />
            </div>
            <div className="form-group">
              <label>Description (optional):</label>
              <input type="text" value={description} onChange={(e) => setDescription(e.target.value)}
                placeholder="Bill payment, transfer, etc." />
            </div>
            <button type="submit" className="btn-primary" disabled={loading}>
              {loading ? 'Sending...' : 'Execute Transfer'}
            </button>
          </form>
        </div>

        <div className="info-card">
          <h3>Transaction Result</h3>
          {result ? (
            <div className="transfer-result">
              <div className="result-status success">✓ Transfer successful</div>
              <table className="info-table">
                <tbody>
                  <tr><td>Transaction ID</td><td><strong>{result.transaction_id}</strong></td></tr>
                  <tr><td>Status</td><td><span className="badge badge-success">{result.status}</span></td></tr>
                  <tr><td>Amount</td><td>{parseFloat(result.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })} RSD</td></tr>
                  <tr><td>Time</td><td>{new Date(result.timestamp).toLocaleString('en-US')}</td></tr>
                </tbody>
              </table>

              <div className="info-box">
                <h4>📡 API Response (RAW)</h4>
                <pre>{JSON.stringify(result, null, 2)}</pre>
              </div>
            </div>
          ) : (
            <p className="text-muted">Execute a transfer to see the result.</p>
          )}
        </div>
      </div>

      <div className="info-card">
        <h3>ℹ️ How Transfer Works</h3>
        <div className="security-features">
          <div className="security-item">
            <span className="security-check">1</span>
            <span>JWT token is sent in Authorization header</span>
          </div>
          <div className="security-item">
            <span className="security-check">2</span>
            <span>Backend verifies token and checks RBAC permissions</span>
          </div>
          <div className="security-item">
            <span className="security-check">3</span>
            <span>Checks if you have access to the source account</span>
          </div>
          <div className="security-item">
            <span className="security-check">4</span>
            <span>Balance is decrypted (AES-256), updated, and re-encrypted</span>
          </div>
          <div className="security-item">
            <span className="security-check">5</span>
            <span>Transaction is recorded in the audit log</span>
          </div>
        </div>
      </div>
    </div>
  );
}
