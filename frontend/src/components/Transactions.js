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
      setError(err.error || 'Error loading transactions');
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
      <h2>📜 Transaction History</h2>
      <p className="page-subtitle">View transactions for an account</p>

      <div className="info-card">
        <form onSubmit={handleSearch} className="form-inline">
          <div className="form-group">
            <label>Account ID:</label>
            <input type="number" value={inputId} onChange={(e) => setInputId(e.target.value)}
              placeholder="Enter account ID" required />
          </div>
          <button type="submit" className="btn-primary" disabled={loading}>
            {loading ? 'Loading...' : 'Show Transactions'}
          </button>
        </form>
      </div>

      {error && <div className="error-message">{error}</div>}

      {transactions.length > 0 ? (
        <div className="info-card">
          <h3>Transactions ({transactions.length})</h3>
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Amount (RSD)</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((t) => (
                  <tr key={t.transaction_id}>
                    <td><strong>#{t.transaction_id}</strong></td>
                    <td className="amount">
                      {parseFloat(t.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </td>
                    <td>{t.description}</td>
                    <td>
                      <span className={`badge badge-${t.status}`}>{t.status}</span>
                    </td>
                    <td>{new Date(t.created_at).toLocaleString('en-US')}</td>
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
              {accountId ? 'No transactions for this account.' : 'Enter an account ID to view transactions.'}
            </p>
          </div>
        )
      )}

      <div className="info-card">
        <p className="text-muted">
          💡 Create accounts on the <Link to="/accounts">accounts page</Link> and
          make a transfer on the <Link to="/transfer">transfer page</Link> to see transactions.
        </p>
      </div>
    </div>
  );
}
