import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';

export default function Accounts({ user }) {
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [creating, setCreating] = useState(false);
  const [accountType, setAccountType] = useState('checking');
  const [initialBalance, setInitialBalance] = useState('');
  const [message, setMessage] = useState('');

  const isTeller = user?.role === 'teller';
  const isAdmin = user?.role === 'admin';
  const canCreate = !isTeller; // teller doesn't create, only views

  const loadAccounts = async () => {
    try {
      const data = await api.listAccounts();
      setAccounts(data.accounts || []);
    } catch (err) {
      setError(err.error || 'Error loading accounts');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadAccounts(); }, []);

  const handleCreate = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setCreating(true);
    try {
      const data = await api.createAccount(accountType, parseFloat(initialBalance) || 0);
      setMessage(`Account created: ${data.account_number}`);
      setInitialBalance('');
      loadAccounts();
    } catch (err) {
      setError(err.error || 'Error creating account');
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="page">
      <h2>{isTeller ? '🏦 View All Accounts' : 'Bank Accounts'}</h2>
      <p className="page-subtitle">
        {isTeller ? 'View accounts of all bank clients' : 'Create and view accounts'}
      </p>

      {error && <div className="error-message">{error}</div>}
      {message && <div className="success-message">{message}</div>}

      {isTeller || isAdmin ? (
        /* Table view for teller and admin */
        <div className="info-card">
          <div className="card-header">
            <h3>All Accounts ({accounts.length})</h3>
            <button onClick={loadAccounts} className="btn-small" disabled={loading}>
              {loading ? '...' : '🔄 Refresh'}
            </button>
          </div>
          {loading ? (
            <p className="text-muted">Loading accounts...</p>
          ) : accounts.length === 0 ? (
            <p className="text-muted">No accounts in the system.</p>
          ) : (
            <div className="table-responsive">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Account Number</th>
                    <th>Owner</th>
                    <th>Email</th>
                    <th>Type</th>
                    <th>Balance (RSD)</th>
                    <th>Created</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {accounts.map((acc) => (
                    <tr key={acc.account_id}>
                      <td>{acc.account_id}</td>
                      <td className="mono">{acc.account_number}</td>
                      <td><strong>{acc.user_name || '-'}</strong></td>
                      <td>{acc.user_email || '-'}</td>
                      <td>
                        <span className={`badge badge-${acc.account_type}`}>
                          {acc.account_type === 'checking' ? 'Checking' : 'Savings'}
                        </span>
                      </td>
                      <td className="amount">
                        {parseFloat(acc.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </td>
                      <td>{new Date(acc.created_at).toLocaleDateString('en-US')}</td>
                      <td>
                        <Link to={`/transactions/${acc.account_id}`} className="btn-small">
                          📜 Transactions
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      ) : (
        /* Cards for customer */
        <div className="grid-2">
          {canCreate && (
            <div className="info-card">
              <h3>Create New Account</h3>
              <form onSubmit={handleCreate} className="form">
                <div className="form-group">
                  <label>Account Type:</label>
                  <select value={accountType} onChange={(e) => setAccountType(e.target.value)}>
                    <option value="checking">Checking</option>
                    <option value="savings">Savings</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Initial Balance (RSD):</label>
                  <input type="number" min="0" step="0.01" value={initialBalance}
                    onChange={(e) => setInitialBalance(e.target.value)}
                    placeholder="5000" required />
                </div>
                <button type="submit" className="btn-primary" disabled={creating}>
                  {creating ? 'Creating...' : 'Create Account'}
                </button>
              </form>
            </div>
          )}

          <div className="info-card">
            <h3>My Accounts</h3>
            {loading ? (
              <p className="text-muted">Loading accounts...</p>
            ) : accounts.length === 0 ? (
              <p className="text-muted">You have no accounts. Create a new account.</p>
            ) : (
              <div className="accounts-list">
                {accounts.map((acc) => (
                  <div key={acc.account_id} className="account-item">
                    <div className="account-header">
                      <span className={`account-type badge badge-${acc.account_type}`}>
                        {acc.account_type === 'checking' ? '💳 Checking' : '🏦 Savings'}
                      </span>
                      <span className="account-id">ID: {acc.account_id}</span>
                    </div>
                    <div className="account-number">{acc.account_number}</div>
                    <div className="account-balance">
                      {parseFloat(acc.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })} RSD
                    </div>
                    <div className="account-date">
                      Created: {new Date(acc.created_at).toLocaleDateString('en-US')}
                    </div>
                    <Link to={`/transactions/${acc.account_id}`} className="btn-small">
                      📜 Transactions
                    </Link>
                  </div>
                ))}
              </div>
            )}
            <button onClick={loadAccounts} className="btn-secondary" style={{ marginTop: 12 }}>
              🔄 Refresh Accounts
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
