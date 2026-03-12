import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { parseToken } from '../api';

export default function Navbar({ user, onLogout }) {
  const navigate = useNavigate();
  const token = localStorage.getItem('token');
  const tokenInfo = token ? parseToken(token) : null;

  const handleLogout = () => {
    onLogout();
    navigate('/login');
  };

  return (
    <nav className="navbar">
      <div className="navbar-brand">🏦 Banking App</div>
      <div className="navbar-links">
        <NavLink to="/">Početna</NavLink>
        <NavLink to="/accounts">{user?.role === 'teller' ? 'Pregled računa' : 'Računi'}</NavLink>
        <NavLink to="/transfer">Transfer</NavLink>
        {user?.role === 'admin' && <NavLink to="/admin">Admin</NavLink>}
        <NavLink to="/token-info">🔑 Token</NavLink>
      </div>
      <div className="navbar-user">
        <span className="navbar-role">{user?.role?.toUpperCase()}</span>
        <span className="navbar-name">{user?.full_name}</span>
        {tokenInfo && (
          <span className={`navbar-token-status ${tokenInfo.isExpired ? 'expired' : 'valid'}`}>
            {tokenInfo.isExpired ? '⚠ Token istekao' : '✓ Token aktivan'}
          </span>
        )}
        <button onClick={handleLogout} className="btn-logout">Odjavi se</button>
      </div>
    </nav>
  );
}
