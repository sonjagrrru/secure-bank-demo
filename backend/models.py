"""
Database modeli sa enkripcionom zaštitom
"""

from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
from security import EncryptionService
import uuid
import secrets
import bcrypt

db = SQLAlchemy()
encryption_service = EncryptionService()

class User(db.Model):
    """Korisnik sistema"""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    full_name = db.Column(db.String(255), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(50), nullable=False)  # customer, teller, admin
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relacije
    accounts = db.relationship('Account', back_populates='user')
    audit_logs = db.relationship('AuditLog', back_populates='user')
    
    def set_password(self, password):
        """Postavi šifrovanu lozinku"""
        self.password_hash = bcrypt.hashpw(
            password.encode('utf-8'),
            bcrypt.gensalt()
        ).decode('utf-8')
    
    def check_password(self, password):
        """Proveri lozinku"""
        return bcrypt.checkpw(
            password.encode('utf-8'),
            self.password_hash.encode('utf-8')
        )
    
    def __repr__(self):
        return f'<User {self.email}>'

class Account(db.Model):
    """Bankaski račun"""
    __tablename__ = 'accounts'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    account_number = db.Column(db.String(50), unique=True, nullable=False, index=True)
    account_type = db.Column(db.String(50), nullable=False)  # checking, savings
    
    # ENKRIPTOVANO: Žitak i PIN
    _balance_encrypted = db.Column('balance', db.Text, nullable=False)
    
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relacije
    user = db.relationship('User', back_populates='accounts')
    from_transactions = db.relationship('Transaction', foreign_keys='Transaction.from_account_id', backref='from_account')
    to_transactions = db.relationship('Transaction', foreign_keys='Transaction.to_account_id', backref='to_account')
    
    @property
    def balance(self):
        """Dekriptuj saldo"""
        if self._balance_encrypted:
            return float(encryption_service.decrypt(self._balance_encrypted))
        return 0.0
    
    @balance.setter
    def balance(self, value):
        """Enkriptuj saldo"""
        self._balance_encrypted = encryption_service.encrypt(str(value))
    
    @staticmethod
    def generate_account_number():
        """Generiši jedinstveni broj računa"""
        return f"ACC{secrets.token_hex(8).upper()}"
    
    def __repr__(self):
        return f'<Account {self.account_number}>'

class Transaction(db.Model):
    """Transakcija između računa"""
    __tablename__ = 'transactions'
    
    id = db.Column(db.Integer, primary_key=True)
    from_account_id = db.Column(db.Integer, db.ForeignKey('accounts.id'), nullable=False)
    to_account_id = db.Column(db.Integer, db.ForeignKey('accounts.id'), nullable=False)
    
    # ENKRIPTOVANO: Iznos
    _amount_encrypted = db.Column('amount', db.Text, nullable=False)
    
    description = db.Column(db.String(255))
    status = db.Column(db.String(50), nullable=False)  # completed, pending, failed
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    @property
    def amount(self):
        """Dekriptuj iznos"""
        if self._amount_encrypted:
            return float(encryption_service.decrypt(self._amount_encrypted))
        return 0.0
    
    @amount.setter
    def amount(self, value):
        """Enkriptuj iznos"""
        self._amount_encrypted = encryption_service.encrypt(str(value))
    
    def __repr__(self):
        return f'<Transaction {self.id}>'

class AuditLog(db.Model):
    """Audit log - pregled svih akcija"""
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    action = db.Column(db.String(100), nullable=False, index=True)
    details = db.Column(db.Text)
    status = db.Column(db.String(50), nullable=False)  # success, failed
    ip_address = db.Column(db.String(45))  # IPv4 i IPv6
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    # Relacija
    user = db.relationship('User', back_populates='audit_logs')
    
    def __repr__(self):
        return f'<AuditLog {self.action}>'
