-- Inicijalizacija baze podataka sa enkripcionom zaštitom

-- Kreiraj extension za UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Kreiraj users tabelu
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'customer',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Kreiraj accounts tabelu sa enkripcionim balansom
CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_number VARCHAR(50) UNIQUE NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    balance TEXT NOT NULL,  -- Enkriptovano
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_account_number ON accounts(account_number);

-- Kreiraj transactions tabelu sa enkripcionim iznosom
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    from_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    to_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    amount TEXT NOT NULL,  -- Enkriptovano
    description VARCHAR(255),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);

-- Kreiraj audit_logs tabelu
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    status VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);

-- Kreiraj trigger za ažuriranje updated_at kolone
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert test korisnika (lozinka: admin123)
INSERT INTO users (email, full_name, password_hash, role) VALUES
(
    'admin@banking.local',
    'Administrator',
    '$2b$12$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e',
    'admin'
) ON CONFLICT (email) DO NOTHING;

INSERT INTO users (email, full_name, password_hash, role) VALUES
(
    'teller@banking.local',
    'Blagajnik',
    '$2b$12$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e',
    'teller'
) ON CONFLICT (email) DO NOTHING;

INSERT INTO users (email, full_name, password_hash, role) VALUES
(
    'customer@banking.local',
    'Kupac',
    '$2b$12$P4aENKMc43CjrT1l0WZOZubTbilnUp/Xz6TCafq1/sDtvGm6/pL0e',
    'customer'
) ON CONFLICT (email) DO NOTHING;

-- Dozvole za bazu podataka
GRANT CONNECT ON DATABASE banking_db TO banking_user;
GRANT USAGE ON SCHEMA public TO banking_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO banking_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO banking_user;

COMMIT;
