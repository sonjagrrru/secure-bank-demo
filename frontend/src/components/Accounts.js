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
  const canCreate = !isTeller; // blagajnik ne kreira, samo pregleda

  const loadAccounts = async () => {
    try {
      const data = await api.listAccounts();
      setAccounts(data.accounts || []);
    } catch (err) {
      setError(err.error || 'Greška pri učitavanju računa');
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
      setMessage(`Račun kreiran: ${data.account_number}`);
      setInitialBalance('');
      loadAccounts();
    } catch (err) {
      setError(err.error || 'Greška pri kreiranju računa');
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="page">
      <h2>{isTeller ? '🏦 Pregled svih računa' : 'Bankarski računi'}</h2>
      <p className="page-subtitle">
        {isTeller ? 'Pregled računa svih klijenata banke' : 'Kreirajte i pregledajte račune'}
      </p>

      {error && <div className="error-message">{error}</div>}
      {message && <div className="success-message">{message}</div>}

      {isTeller || isAdmin ? (
        /* Tabelarni prikaz za blagajnika i admina */
        <div className="info-card">
          <div className="card-header">
            <h3>Svi računi ({accounts.length})</h3>
            <button onClick={loadAccounts} className="btn-small" disabled={loading}>
              {loading ? '...' : '🔄 Osveži'}
            </button>
          </div>
          {loading ? (
            <p className="text-muted">Učitavanje računa...</p>
          ) : accounts.length === 0 ? (
            <p className="text-muted">Nema računa u sistemu.</p>
          ) : (
            <div className="table-responsive">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Broj računa</th>
                    <th>Vlasnik</th>
                    <th>Email</th>
                    <th>Tip</th>
                    <th>Stanje (RSD)</th>
                    <th>Kreiran</th>
                    <th>Akcije</th>
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
                          {acc.account_type === 'checking' ? 'Tekući' : 'Štedni'}
                        </span>
                      </td>
                      <td className="amount">
                        {parseFloat(acc.balance).toLocaleString('sr-Latn', { minimumFractionDigits: 2 })}
                      </td>
                      <td>{new Date(acc.created_at).toLocaleDateString('sr-Latn')}</td>
                      <td>
                        <Link to={`/transactions/${acc.account_id}`} className="btn-small">
                          📜 Transakcije
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
        /* Kartice za klijenta */
        <div className="grid-2">
          {canCreate && (
            <div className="info-card">
              <h3>Kreiraj novi račun</h3>
              <form onSubmit={handleCreate} className="form">
                <div className="form-group">
                  <label>Tip računa:</label>
                  <select value={accountType} onChange={(e) => setAccountType(e.target.value)}>
                    <option value="checking">Tekući (Checking)</option>
                    <option value="savings">Štedni (Savings)</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Početni saldo (RSD):</label>
                  <input type="number" min="0" step="0.01" value={initialBalance}
                    onChange={(e) => setInitialBalance(e.target.value)}
                    placeholder="5000" required />
                </div>
                <button type="submit" className="btn-primary" disabled={creating}>
                  {creating ? 'Kreiranje...' : 'Kreiraj račun'}
                </button>
              </form>
            </div>
          )}

          <div className="info-card">
            <h3>Moji računi</h3>
            {loading ? (
              <p className="text-muted">Učitavanje računa...</p>
            ) : accounts.length === 0 ? (
              <p className="text-muted">Nemate račune. Kreirajte novi račun.</p>
            ) : (
              <div className="accounts-list">
                {accounts.map((acc) => (
                  <div key={acc.account_id} className="account-item">
                    <div className="account-header">
                      <span className={`account-type badge badge-${acc.account_type}`}>
                        {acc.account_type === 'checking' ? '💳 Tekući' : '🏦 Štedni'}
                      </span>
                      <span className="account-id">ID: {acc.account_id}</span>
                    </div>
                    <div className="account-number">{acc.account_number}</div>
                    <div className="account-balance">
                      {parseFloat(acc.balance).toLocaleString('sr-Latn', { minimumFractionDigits: 2 })} RSD
                    </div>
                    <div className="account-date">
                      Kreiran: {new Date(acc.created_at).toLocaleDateString('sr-Latn')}
                    </div>
                    <Link to={`/transactions/${acc.account_id}`} className="btn-small">
                      📜 Transakcije
                    </Link>
                  </div>
                ))}
              </div>
            )}
            <button onClick={loadAccounts} className="btn-secondary" style={{ marginTop: 12 }}>
              🔄 Osveži račune
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
