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
      setError(err.error || 'Greška pri transferu');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page">
      <h2>💸 Transfer novca</h2>
      <p className="page-subtitle">Prenesite novac između računa</p>

      <div className="grid-2">
        <div className="info-card">
          <h3>Nova transakcija</h3>

          {error && <div className="error-message">{error}</div>}

          <form onSubmit={handleTransfer} className="form">
            <div className="form-group">
              <label>Sa računa (ID):</label>
              <input type="number" value={fromId} onChange={(e) => setFromId(e.target.value)}
                placeholder="ID izvornog računa" required />
            </div>
            <div className="form-group">
              <label>Na račun (ID):</label>
              <input type="number" value={toId} onChange={(e) => setToId(e.target.value)}
                placeholder="ID odredišnog računa" required />
            </div>
            <div className="form-group">
              <label>Iznos (RSD):</label>
              <input type="number" min="0.01" step="0.01" value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="1000.00" required />
            </div>
            <div className="form-group">
              <label>Opis (opciono):</label>
              <input type="text" value={description} onChange={(e) => setDescription(e.target.value)}
                placeholder="Plaćanje računa, transfer, itd." />
            </div>
            <button type="submit" className="btn-primary" disabled={loading}>
              {loading ? 'Slanje...' : 'Izvrši transfer'}
            </button>
          </form>
        </div>

        <div className="info-card">
          <h3>Rezultat transakcije</h3>
          {result ? (
            <div className="transfer-result">
              <div className="result-status success">✓ Transfer uspešan</div>
              <table className="info-table">
                <tbody>
                  <tr><td>ID transakcije</td><td><strong>{result.transaction_id}</strong></td></tr>
                  <tr><td>Status</td><td><span className="badge badge-success">{result.status}</span></td></tr>
                  <tr><td>Iznos</td><td>{parseFloat(result.amount).toLocaleString('sr-Latn', { minimumFractionDigits: 2 })} RSD</td></tr>
                  <tr><td>Vreme</td><td>{new Date(result.timestamp).toLocaleString('sr-Latn')}</td></tr>
                </tbody>
              </table>

              <div className="info-box">
                <h4>📡 API Response (RAW)</h4>
                <pre>{JSON.stringify(result, null, 2)}</pre>
              </div>
            </div>
          ) : (
            <p className="text-muted">Izvršite transfer da vidite rezultat.</p>
          )}
        </div>
      </div>

      <div className="info-card">
        <h3>ℹ️ Kako funkcioniše transfer</h3>
        <div className="security-features">
          <div className="security-item">
            <span className="security-check">1</span>
            <span>JWT token se šalje u Authorization headeru</span>
          </div>
          <div className="security-item">
            <span className="security-check">2</span>
            <span>Backend verifikuje token i proverava RBAC dozvole</span>
          </div>
          <div className="security-item">
            <span className="security-check">3</span>
            <span>Proverava se da li imate pristup izvornom računu</span>
          </div>
          <div className="security-item">
            <span className="security-check">4</span>
            <span>Saldo se dekriptuje (AES-256), ažurira i ponovo enkriptuje</span>
          </div>
          <div className="security-item">
            <span className="security-check">5</span>
            <span>Transakcija se evidentira u audit logu</span>
          </div>
        </div>
      </div>
    </div>
  );
}
