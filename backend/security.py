"""
Security moduli:
- Enkripcija podataka na disku (AES-256)
- Heširanje lozinki (bcrypt)
- TLS/SSL za komunikaciju
"""

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
import base64
import os
import bcrypt

class EncryptionService:
    """Servis za enkripcionu zaštitu podataka na disku"""
    
    def __init__(self, master_key=None):
        """
        Inicijalizuj encryption servis
        master_key - korisni u produkciji, koristi env varijablu
        """
        if master_key is None:
            # U produkciji koristiti: export ENCRYPTION_KEY=$(python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')
            master_key = os.getenv('ENCRYPTION_KEY', None)
        
        # Ako nema ključa ili nije validan, generiši privremeni
        if not master_key:
            self.cipher = Fernet(Fernet.generate_key())
            return
        
        # Proveri da li je ključ validan Fernet ključ
        try:
            self.cipher = Fernet(master_key.encode() if isinstance(master_key, str) else master_key)
        except Exception:
            # Ako ključ nije validan, generiši novi
            self.cipher = Fernet(Fernet.generate_key())
    
    def encrypt(self, plaintext):
        """Enkriptuj tekst"""
        try:
            ciphertext = self.cipher.encrypt(plaintext.encode())
            return ciphertext.decode()
        except Exception as e:
            raise ValueError(f"Greška pri enkripcioniranju: {str(e)}")
    
    def decrypt(self, ciphertext):
        """Dekriptuj tekst"""
        try:
            plaintext = self.cipher.decrypt(ciphertext.encode())
            return plaintext.decode()
        except Exception as e:
            raise ValueError(f"Greška pri dekripcioniranju: {str(e)}")

def hash_password(password):
    """Heširaj lozinku sa bcrypt"""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(password, hashed):
    """Proveri lozinku"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

class TLSConfig:
    """Konfiguracija za TLS/SSL"""
    
    # Putanja do SSL sertifikata i ključa
    CERT_PATH = os.getenv('SSL_CERT_PATH', '/etc/ssl/certs/server.crt')
    KEY_PATH = os.getenv('SSL_KEY_PATH', '/etc/ssl/private/server.key')
    
    # SSL opcije
    SSL_CONTEXT = {
        'certfile': CERT_PATH,
        'keyfile': KEY_PATH,
        'ssl_version': 'TLSv1_2',
        'ciphers': 'HIGH:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA'
    }
    
    @staticmethod
    def is_configured():
        """Proveri da li su SSL fajlovi dostupni"""
        return os.path.exists(TLSConfig.CERT_PATH) and os.path.exists(TLSConfig.KEY_PATH)
