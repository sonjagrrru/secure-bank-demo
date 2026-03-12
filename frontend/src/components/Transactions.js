import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { api } from '../api';

export default function Transactions() {
  const { accountId } = useParams();
  const [transactions, setTransactions] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [inputId, setInputId] = useState(accountId || '');

  const loadTransactions = async (id) => {
    if (!id) return;
    setLoading(true);
    setError('');
    try {
      const data = await api.getTransactions(parseInt(id));
      setTransactions(data.transactions || []);
    } catch (err) {
      setError(err.error || 'Greška pri učitavanju transakcija');
      setTransactions([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (accountId) loadTransactions(accountId);
  }, [accountId]);

  const handleSearch = (e) => {
    e.preventDefault();
    loadTransactions(inputId);
  };

  return (
    <div className="page">
      <h2>📜 Istorija transakcija</h2>
      <p className="page-subtitle">Pregled transakcija za račun</p>

      <div className="info-card">
        <form onSubmit={handleSearch} className="form-inline">
          <div className="form-group">
            <label>ID računa:</label>
            <input type="number" value={inputId} onChange={(e) => setInputId(e.target.value)}
              placeholder="Unesite ID računa" required />
          </div>
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? 'Učitavanje...' : 'Prikaži transakcije'}
          </button>
        </form>
      </div>

      {error && <div className="error-message">{error}</div>}

      {transactions.length > 0 ? (
        <div className="info-card">
          <h3>Transakcije ({transactions.length})</h3>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Iznos (RSD)</th>
                  <th>Opis</th>
                  <th>Status</th>
                  <th>Datum</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((t) => (
                  <tr key={t.transaction_id}>
                    <td><strong>#{t.transaction_id}</strong></td>
                    <td className="amount">
                      {parseFloat(t.amount).toLocaleString('sr-Latn', { minimumFractionDigits: 2 })}
                    </td>
                    <td>{t.description}</td>
                    <td>
                      <span className={`badge badge-${t.status}`}>{t.status}</span>
                    </td>
                    <td>{new Date(t.created_at).toLocaleString('sr-Latn')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        !loading && !error && (
          <div className="info-card">
            <p className="text-muted text-center">
              {accountId ? 'Nema transakcija za ovaj račun.' : 'Unesite ID računa da vidite transakcije.'}
            </p>
          </div>
        )
      )}

      <div className="info-card">
        <p className="text-muted">
          💡 Kreirajte račune na <Link to="/accounts">stranici računa</Link> i
          izvršite transfer na <Link to="/transfer">stranici transfera</Link> da biste videli transakcije.
        </p>
      </div>
    </div>
  );
}
