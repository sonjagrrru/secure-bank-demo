import React, { useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import './App.css';
import Navbar from './components/Navbar';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import Accounts from './components/Accounts';
import Transfer from './components/Transfer';
import Transactions from './components/Transactions';
import AdminPanel from './components/AdminPanel';
import TokenInfo from './components/TokenInfo';
import { parseToken, startAutoRefresh, stopAutoRefresh } from './api';

function App() {
  const [user, setUser] = useState(() => {
    // Restore session from token if exists
    const token = localStorage.getItem('token');
    const saved = localStorage.getItem('user');
    if (token && saved) {
      const info = parseToken(token);
      if (info && !info.isExpired) {
        startAutoRefresh();
        return JSON.parse(saved);
      }
      localStorage.removeItem('token');
      localStorage.removeItem('user');
    }
    return null;
  });

  const handleLogin = (data) => {
    setUser(data);
    localStorage.setItem('user', JSON.stringify(data));
    startAutoRefresh();
  };

  const handleLogout = () => {
    stopAutoRefresh();
    setUser(null);
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  };

  if (!user) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <BrowserRouter>
      <div className="App">
        <Navbar user={user} onLogout={handleLogout} />
        <main className="main-content">
          <Routes>
            <Route path="/" element={<Dashboard user={user} />} />
            <Route path="/accounts" element={<Accounts user={user} />} />
            <Route path="/transfer" element={<Transfer />} />
            <Route path="/transactions/:accountId" element={<Transactions />} />
            <Route path="/transactions" element={<Transactions />} />
            <Route path="/token-info" element={<TokenInfo />} />
            {user.role === 'admin' && (
              <Route path="/admin" element={<AdminPanel />} />
            )}
            <Route path="*" element={<Navigate to="/" />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}

export default App;
