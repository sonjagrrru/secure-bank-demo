import React, { useState } from 'react';
import { api } from '../api';

export default function AdminPanel() {
  const [users, setUsers] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [activeTab, setActiveTab] = useState('users');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const loadUsers = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await api.getUsers();
      setUsers(data.users || []);
    } catch (err) {
      setError(err.error || 'Error loading users');
    } finally {
      setLoading(false);
    }
  };

  const loadAuditLog = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await api.getAuditLog();
      setAuditLogs(data.audit_logs || []);
    } catch (err) {
      setError(err.error || 'Error loading audit log');
    } finally {
      setLoading(false);
    }
  };

  const handleTabChange = (tab) => {
    setActiveTab(tab);
    setError('');
    if (tab === 'users' && users.length === 0) loadUsers();
    if (tab === 'audit' && auditLogs.length === 0) loadAuditLog();
  };

  return (
    <div className="page">
      <h2>⚙️ Admin Panel</h2>
      <p className="page-subtitle">User management and audit log review</p>

      {error && <div className="error-message">{error}</div>}

      <div className="tabs">
        <button className={`tab ${activeTab === 'users' ? 'active' : ''}`}
          onClick={() => handleTabChange('users')}>
          👥 Users
        </button>
        <button className={`tab ${activeTab === 'audit' ? 'active' : ''}`}
          onClick={() => handleTabChange('audit')}>
          📋 Audit Log
        </button>
      </div>

      {activeTab === 'users' && (
        <div className="info-card">
          <div className="card-header">
            <h3>Users ({users.length})</h3>
            <button onClick={loadUsers} className="btn-small" disabled={loading}>
              {loading ? '...' : '🔄 Refresh'}
            </button>
          </div>
          {users.length > 0 ? (
            <div className="table-responsive">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Email</th>
                    <th>Name</th>
                    <th>Role</th>
                    <th>Registered</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => (
                    <tr key={u.user_id}>
                      <td>{u.user_id}</td>
                      <td><strong>{u.email}</strong></td>
                      <td>{u.full_name}</td>
                      <td><span className={`badge badge-${u.role}`}>{u.role}</span></td>
                      <td>{new Date(u.created_at).toLocaleDateString('en-US')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-muted">Click "Refresh" to load users.</p>
          )}
        </div>
      )}

      {activeTab === 'audit' && (
        <div className="info-card">
          <div className="card-header">
            <h3>Audit Log ({auditLogs.length})</h3>
            <button onClick={loadAuditLog} className="btn-small" disabled={loading}>
              {loading ? '...' : '🔄 Refresh'}
            </button>
          </div>
          {auditLogs.length > 0 ? (
            <div className="table-responsive">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>User</th>
                    <th>Action</th>
                    <th>Details</th>
                    <th>Status</th>
                    <th>IP</th>
                    <th>Time</th>
                  </tr>
                </thead>
                <tbody>
                  {auditLogs.map((log) => (
                    <tr key={log.id}>
                      <td>{log.id}</td>
                      <td>{log.user_email || log.user_id || '-'}</td>
                      <td><span className="badge badge-action">{log.action}</span></td>
                      <td className="details-cell">{log.details}</td>
                      <td>
                        <span className={`badge badge-${log.status}`}>{log.status}</span>
                      </td>
                      <td className="mono">{log.ip_address}</td>
                      <td>{new Date(log.timestamp).toLocaleString('en-US')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-muted">Click "Refresh" to load audit logs.</p>
          )}
        </div>
      )}
    </div>
  );
}
