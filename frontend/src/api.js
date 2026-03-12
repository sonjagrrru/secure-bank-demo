const API_BASE = `${window.location.origin}/api`;

function getToken() {
  return localStorage.getItem('token');
}

function authHeaders() {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request(method, path, body) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
  };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(`${API_BASE}${path}`, opts);
  const data = await res.json();
  if (!res.ok) throw { status: res.status, ...data };
  return data;
}

// ============= AUTO TOKEN REFRESH =============
let refreshTimer = null;

export function startAutoRefresh() {
  stopAutoRefresh();
  refreshTimer = setInterval(async () => {
    const token = getToken();
    if (!token) return;
    const info = parseToken(token);
    if (!info) return;

    // Refresh 15 seconds before expiry
    const msLeft = info.expires - Date.now();
    if (msLeft < 15000 && msLeft > -300000) {
      try {
        const data = await request('POST', '/auth/refresh');
        localStorage.setItem('token', data.token);
        console.log('[AUTH] Token refreshed automatically');
      } catch (e) {
        console.warn('[AUTH] Token refresh failed:', e);
      }
    }
  }, 5000); // check every 5s
}

export function stopAutoRefresh() {
  if (refreshTimer) {
    clearInterval(refreshTimer);
    refreshTimer = null;
  }
}

export const api = {
  // Auth
  login: (email, password) => request('POST', '/auth/login', { email, password }),
  register: (email, full_name, password) => request('POST', '/auth/register', { email, full_name, password }),
  refreshToken: () => request('POST', '/auth/refresh'),

  // Health
  health: () => request('GET', '/health'),

  // Accounts
  listAccounts: () => request('GET', '/accounts'),
  createAccount: (account_type, initial_balance) =>
    request('POST', '/accounts', { account_type, initial_balance }),
  getAccount: (id) => request('GET', `/accounts/${id}`),

  // Transactions
  transfer: (from_account_id, to_account_id, amount, description) =>
    request('POST', '/transactions/transfer', { from_account_id, to_account_id, amount, description }),
  getTransactions: (accountId) => request('GET', `/transactions/${accountId}`),

  // Admin
  getUsers: () => request('GET', '/admin/users'),
  getAuditLog: () => request('GET', '/admin/audit-log'),
};

export function parseToken(token) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return {
      user_id: payload.user_id,
      role: payload.role,
      issued: new Date(payload.iat * 1000),
      expires: new Date(payload.exp * 1000),
      isExpired: Date.now() > payload.exp * 1000,
      raw: token,
    };
  } catch {
    return null;
  }
}
