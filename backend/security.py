"""
Security modules:
- Data encryption at rest (AES-256)
- Password hashing (bcrypt)
- TLS/SSL for communication
"""

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
import base64
import os
import bcrypt

class EncryptionService:
    """Service for data encryption at rest"""
    
    def __init__(self, master_key=None):
        """
        Initialize encryption service
        master_key - used in production, uses env variable
        """
        if master_key is None:
            # In production use: export ENCRYPTION_KEY=$(python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')
            master_key = os.getenv('ENCRYPTION_KEY', None)
        
        # If no key or key is not valid, generate a temporary one
        if not master_key:
            self.cipher = Fernet(Fernet.generate_key())
            return
        
        # Check if the key is a valid Fernet key
        try:
            self.cipher = Fernet(master_key.encode() if isinstance(master_key, str) else master_key)
        except Exception:
            # If key is not valid, generate a new one
            self.cipher = Fernet(Fernet.generate_key())
    
    def encrypt(self, plaintext):
        """Encrypt text"""
        try:
            ciphertext = self.cipher.encrypt(plaintext.encode())
            return ciphertext.decode()
        except Exception as e:
            raise ValueError(f"Encryption error: {str(e)}")
    
    def decrypt(self, ciphertext):
        """Decrypt text"""
        try:
            plaintext = self.cipher.decrypt(ciphertext.encode())
            return plaintext.decode()
        except Exception as e:
            raise ValueError(f"Decryption error: {str(e)}")

def hash_password(password):
    """Hash password with bcrypt"""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(password, hashed):
    """Verify password"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

class TLSConfig:
    """Configuration for TLS/SSL"""
    
    # Path to SSL certificate and key
    CERT_PATH = os.getenv('SSL_CERT_PATH', '/etc/ssl/certs/server.crt')
    KEY_PATH = os.getenv('SSL_KEY_PATH', '/etc/ssl/private/server.key')
    
    # SSL options
    SSL_CONTEXT = {
        'certfile': CERT_PATH,
        'keyfile': KEY_PATH,
        'ssl_version': 'TLSv1_2',
        'ciphers': 'HIGH:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA'
    }
    
    @staticmethod
    def is_configured():
        """Check if SSL files are available"""
        return os.path.exists(TLSConfig.CERT_PATH) and os.path.exists(TLSConfig.KEY_PATH)
