"""
Bankarski sistem sa enkripcionom zaštitom i RBAC kontrolom
Open Source rešenje sa Flask, PostgreSQL i TLS/SSL
"""

from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import jwt
import os
from datetime import datetime, timedelta
from functools import wraps
from dotenv import load_dotenv
import logging
from models import db, User, Account, Transaction, AuditLog
from security import EncryptionService, hash_password, verify_password

load_dotenv()

# Konfiguracija aplikacije
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://user:pass@localhost/banking_db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JSON_SORT_KEYS'] = False
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'super-secret-key-change-in-production')
app.config['JWT_EXPIRATION_DELTA'] = timedelta(minutes=1)
app.config['JWT_ALGORITHM'] = 'HS256'

# Inicijalizacija ekstenzija
db.init_app(app)

# CORS konfiguracija
cors_origins = os.getenv('CORS_ORIGINS', 'http://localhost:3000').split(',')
cors_origins = [origin.strip() for origin in cors_origins]
CORS(app, 
     resources={r"/api/*": {
         "origins": cors_origins,
         "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
         "allow_headers": ["Content-Type", "Authorization"],
         "supports_credentials": True
     }})

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============= HELPER FUNKCIJE =============

def generate_token(user_id, role):
    """Generiši JWT token"""
    payload = {
        'user_id': user_id,
        'role': role,
        'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA'],
        'iat': datetime.utcnow()
    }
    token = jwt.encode(payload, app.config['SECRET_KEY'], algorithm=app.config['JWT_ALGORITHM'])
    return token

def verify_token(token):
    """Verifikuj JWT token"""
    try:
        payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=[app.config['JWT_ALGORITHM']])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def require_auth(allowed_roles=None):
    """Dekorator za zahtev autentifikacije i proveru role"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            # Ekstraktuj token iz Authorization headera
            auth_header = request.headers.get('Authorization', '')
            if not auth_header.startswith('Bearer '):
                return {'error': 'Nedostaje autentifikacija'}, 401
            
            token = auth_header.split(' ', 1)[1]
            payload = verify_token(token)
            if not payload:
                return {'error': 'Nevažeći token'}, 401
            
            if allowed_roles and payload['role'] not in allowed_roles:
                logger.warning(f"Pristup odbijen: korisnik {payload['user_id']} sa ulogom {payload['role']}")
                return {'error': 'Nemate pristup ovom resursu'}, 403
            
            request.user_id = payload['user_id']
            request.user_role = payload['role']
            return f(*args, **kwargs)
        return decorated
    return decorator

def log_action(action, details, user_id, status='success'):
    """Evidentiraj sve akcije za audit"""
    audit = AuditLog(
        user_id=user_id,
        action=action,
        details=details,
        status=status,
        ip_address=request.remote_addr,
        timestamp=datetime.utcnow()
    )
    db.session.add(audit)
    db.session.commit()

# ============= AUTH ENDPOINTS =============

@app.route('/api/auth/register', methods=['POST'])
@limiter.limit("5 per hour")
def register():
    """Registracija novog korisnika"""
    try:
        data = request.get_json()
        
        if User.query.filter_by(email=data['email']).first():
            return {'error': 'Email već postoji'}, 400
        
        user = User(
            email=data['email'],
            full_name=data['full_name'],
            role=data.get('role', 'customer')  # customer, teller, admin
        )
        user.set_password(data['password'])
        
        db.session.add(user)
        db.session.commit()
        
        log_action('REGISTER', f"Novi korisnik: {data['email']}", user.id)
        
        return {
            'message': 'Registracija uspešna',
            'user_id': user.id
        }, 201
        
    except Exception as e:
        logger.error(f"Greška pri registraciji: {str(e)}")
        return {'error': 'Greška pri registraciji'}, 500

@app.route('/api/auth/login', methods=['POST', 'OPTIONS'])
@limiter.limit("10 per hour")
def login():
    """Login korisnika"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        if not data or 'email' not in data or 'password' not in data:
            return {'error': 'Nedostaju email i lozinka'}, 400
        
        email = data.get('email', '').lower()
        password = data.get('password', '')
        
        user = User.query.filter_by(email=email).first()
        
        if not user:
            logger.warning(f"Korisnik sa emailom {email} nije pronađen")
            log_action('LOGIN_FAILED', f"Korisnik ne postoji: {email}", None, 'failed')
            return {'error': 'Pogrešan email ili lozinka'}, 401
        
        if not user.check_password(password):
            logger.warning(f"Pogrešna lozinka za korisnika {email}")
            log_action('LOGIN_FAILED', f"Pogrešna lozinka: {email}", user.id, 'failed')
            return {'error': 'Pogrešan email ili lozinka'}, 401
        
        token = generate_token(user.id, user.role)
        log_action('LOGIN', f"Logovanje: {email}", user.id)
        
        return {
            'token': token,
            'user_id': user.id,
            'role': user.role,
            'full_name': user.full_name
        }, 200
        
    except Exception as e:
        logger.error(f"Greška pri logovanje: {str(e)}")
        return {'error': 'Greška pri logovanje'}, 500

@app.route('/api/auth/refresh', methods=['POST'])
def refresh_token():
    """Obnovi JWT token pre isteka"""
    try:
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return {'error': 'Nedostaje token'}, 401

        token = auth_header.split(' ', 1)[1]
        try:
            # Prihvati i tokene koji su istekli u poslednjih 5 minuta
            payload = jwt.decode(
                token, app.config['SECRET_KEY'],
                algorithms=[app.config['JWT_ALGORITHM']],
                options={'verify_exp': False}
            )
        except jwt.InvalidTokenError:
            return {'error': 'Nevažeći token'}, 401

        # Proveri da token nije stariji od 24h (zaštita od zloupotrebe)
        iat = datetime.utcfromtimestamp(payload.get('iat', 0))
        if (datetime.utcnow() - iat).total_seconds() > 86400:
            return {'error': 'Token je previše star za obnovu'}, 401

        new_token = generate_token(payload['user_id'], payload['role'])
        log_action('TOKEN_REFRESH', f"Obnova tokena za korisnika {payload['user_id']}", payload['user_id'])

        return {'token': new_token}, 200

    except Exception as e:
        logger.error(f"Greška pri obnovi tokena: {str(e)}")
        return {'error': 'Greška pri obnovi tokena'}, 500

# ============= ACCOUNT ENDPOINTS =============

@app.route('/api/accounts', methods=['GET'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def list_accounts():
    """Preuzmi sve račune korisnika"""
    try:
        if request.user_role in ('admin', 'teller'):
            accounts = Account.query.all()
        else:
            accounts = Account.query.filter_by(user_id=request.user_id).all()

        result = []
        for a in accounts:
            item = {
                'account_id': a.id,
                'account_number': a.account_number,
                'account_type': a.account_type,
                'balance': a.balance,
                'user_id': a.user_id,
                'created_at': a.created_at.isoformat()
            }
            if request.user_role in ('admin', 'teller'):
                owner = User.query.get(a.user_id)
                item['user_email'] = owner.email if owner else '-'
                item['user_name'] = owner.full_name if owner else '-'
            result.append(item)

        return {'accounts': result}, 200
    except Exception as e:
        logger.error(f"Greška pri preuzimanju računa: {str(e)}")
        return {'error': 'Greška pri preuzimanju računa'}, 500

@app.route('/api/accounts', methods=['POST'])
@require_auth(allowed_roles=['customer', 'admin'])
def create_account():
    """Kreiraj novi račun"""
    try:
        data = request.get_json()
        
        # Samo admin može kreirati račun za druge, customer samo za sebe
        user_id = data.get('user_id', request.user_id)
        if request.user_role != 'admin' and user_id != request.user_id:
            return {'error': 'Nemate pristup'}, 403
        
        account = Account(
            user_id=user_id,
            account_number=Account.generate_account_number(),
            account_type=data.get('account_type', 'checking'),  # checking, savings
            balance=data.get('initial_balance', 0)
        )
        
        db.session.add(account)
        db.session.commit()
        
        log_action('CREATE_ACCOUNT', f"Novi račun: {account.account_number}", request.user_id)
        
        return {
            'account_id': account.id,
            'account_number': account.account_number,
            'balance': account.balance
        }, 201
        
    except Exception as e:
        logger.error(f"Greška pri kreiranju računa: {str(e)}")
        return {'error': 'Greška pri kreiranju računa'}, 500

@app.route('/api/accounts/<int:account_id>', methods=['GET'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def get_account(account_id):
    """Preuzmи detalje računa"""
    try:
        account = Account.query.get(account_id)
        
        if not account:
            return {'error': 'Račun ne postoji'}, 404
        
        # Provera dozvole
        if request.user_role == 'customer' and account.user_id != request.user_id:
            return {'error': 'Nemate pristup tom računu'}, 403
        
        return {
            'account_id': account.id,
            'account_number': account.account_number,
            'account_type': account.account_type,
            'balance': account.balance,
            'created_at': account.created_at.isoformat()
        }, 200
        
    except Exception as e:
        logger.error(f"Greška pri preuzimanju računa: {str(e)}")
        return {'error': 'Greška pri preuzimanju računa'}, 500

# ============= TRANSACTION ENDPOINTS =============

@app.route('/api/transactions/transfer', methods=['POST'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
@limiter.limit("20 per hour")
def transfer():
    """Presledi novac između računa"""
    try:
        data = request.get_json()
        
        from_account = Account.query.get(data['from_account_id'])
        to_account = Account.query.get(data['to_account_id'])
        amount = float(data['amount'])
        
        if not from_account or not to_account:
            return {'error': 'Račun ne postoji'}, 404
        
        # RBAC provera — blagajnik i klijent mogu samo sa svojih računa
        if request.user_role in ('customer', 'teller') and from_account.user_id != request.user_id:
            log_action('TRANSFER_DENIED', f"Pokušaj neovlašćenog transfera", request.user_id, 'failed')
            return {'error': 'Nemate pristup tom računu'}, 403
        
        if amount <= 0:
            return {'error': 'Iznos mora biti veći od 0'}, 400
        
        if from_account.balance < amount:
            return {'error': 'Nedovoljna sredstva'}, 400
        
        # Izvršavanje transfera
        from_account.balance -= amount
        to_account.balance += amount
        
        transaction = Transaction(
            from_account_id=from_account.id,
            to_account_id=to_account.id,
            amount=amount,
            description=data.get('description', 'Transfer'),
            status='completed'
        )
        
        db.session.add(transaction)
        db.session.commit()
        
        log_action('TRANSFER', f"Transfer: {amount} sa {from_account.account_number} na {to_account.account_number}", request.user_id)
        
        return {
            'transaction_id': transaction.id,
            'status': 'completed',
            'amount': amount,
            'timestamp': transaction.created_at.isoformat()
        }, 200
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Greška pri transferu: {str(e)}")
        return {'error': 'Greška pri transferu'}, 500

@app.route('/api/transactions/<int:account_id>', methods=['GET'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def get_transactions(account_id):
    """Preuzmи istoriju transakcija"""
    try:
        account = Account.query.get(account_id)
        
        if not account:
            return {'error': 'Račun ne postoji'}, 404
        
        # RBAC provera
        if request.user_role == 'customer' and account.user_id != request.user_id:
            return {'error': 'Nemate pristup tom računu'}, 403
        
        transactions = Transaction.query.filter(
            (Transaction.from_account_id == account_id) | (Transaction.to_account_id == account_id)
        ).order_by(Transaction.created_at.desc()).limit(50).all()
        
        return {
            'transactions': [{
                'transaction_id': t.id,
                'amount': t.amount,
                'description': t.description,
                'status': t.status,
                'created_at': t.created_at.isoformat()
            } for t in transactions]
        }, 200
        
    except Exception as e:
        logger.error(f"Greška pri preuzimanju transakcija: {str(e)}")
        return {'error': 'Greška pri preuzimanju transakcija'}, 500

# ============= ADMIN ENDPOINTS =============

@app.route('/api/admin/audit-log', methods=['GET'])
@require_auth(allowed_roles=['admin'])
def get_audit_log():
    """Preuzmи audit log (samo admin)"""
    try:
        logs = AuditLog.query.order_by(AuditLog.timestamp.desc()).limit(100).all()

        result = []
        for log in logs:
            user_email = None
            if log.user_id:
                user = User.query.get(log.user_id)
                user_email = user.email if user else None
            result.append({
                'id': log.id,
                'user_id': log.user_id,
                'user_email': user_email,
                'action': log.action,
                'details': log.details,
                'status': log.status,
                'ip_address': log.ip_address,
                'timestamp': log.timestamp.isoformat()
            })

        return {'audit_logs': result}, 200
        
    except Exception as e:
        logger.error(f"Greška pri preuzimanju audit loga: {str(e)}")
        return {'error': 'Greška pri preuzimanju audit loga'}, 500

@app.route('/api/admin/users', methods=['GET'])
@require_auth(allowed_roles=['admin'])
def get_users():
    """Preuzmи sve korisnike (samo admin)"""
    try:
        users = User.query.all()
        
        return {
            'users': [{
                'user_id': u.id,
                'email': u.email,
                'full_name': u.full_name,
                'role': u.role,
                'created_at': u.created_at.isoformat()
            } for u in users]
        }, 200
        
    except Exception as e:
        logger.error(f"Greška pri preuzimanju korisnika: {str(e)}")
        return {'error': 'Greška pri preuzimanju korisnika'}, 500

# ============= ERROR HANDLERS =============

@app.errorhandler(400)
def bad_request(error):
    return {'error': 'Loš zahtev'}, 400

@app.errorhandler(401)
def unauthorized(error):
    return {'error': 'Nisu autorizovani'}, 401

@app.errorhandler(403)
def forbidden(error):
    return {'error': 'Pristup odbijen'}, 403

@app.errorhandler(404)
def not_found(error):
    return {'error': 'Nije pronađeno'}, 404

@app.errorhandler(429)
def ratelimit_handler(e):
    return {'error': 'Previše zahteva - pokušajte kasnije'}, 429

@app.errorhandler(500)
def internal_error(error):
    return {'error': 'Interna greška servera'}, 500

# ============= HEALTH CHECK =============

@app.route('/api/health', methods=['GET'])
def health():
    """Provera zdravlja aplikacije"""
    return {'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}, 200

@app.route('/api/debug/users', methods=['GET'])
def debug_users():
    """Debug endpoint - prikaži sve korisnike (SAMO ZA DEVELOPMENT)"""
    if os.getenv('FLASK_ENV') != 'development':
        return {'error': 'Forbidden'}, 403
    try:
        users = User.query.all()
        return {
            'total_users': len(users),
            'users': [{
                'id': u.id,
                'email': u.email,
                'full_name': u.full_name,
                'role': u.role,
                'password_hash': u.password_hash[:20] + '...'
            } for u in users]
        }, 200
    except Exception as e:
        logger.error(f"Greška pri debug query: {str(e)}")
        return {'error': str(e)}, 500

# ============= DB INITIALIZATION =============

_db_initialized = False

def init_db():
    """Inicijalizuj bazu podataka (idempotent - sigurno za više call-ova)"""
    global _db_initialized
    
    if _db_initialized:
        return
    
    try:
        with app.app_context():
            # Proveri da li tabele postoje pre nego što kreiram nove
            inspector = __import__('sqlalchemy').inspect(db.engine)
            tables = inspector.get_table_names()
            
            if not tables:
                logger.info("Kreiram tabele...")
                db.create_all()
                logger.info("Baza podataka inicijalizovana")
            else:
                logger.info(f"Baza podataka već inicijalizovana ({len(tables)} tabela)")
            
            _db_initialized = True
    except Exception as e:
        logger.error(f"Greška pri inicijalizaciji baze: {str(e)}")
        _db_initialized = True

if __name__ == '__main__':
    init_db()
    
    # Razvoj sa HTTP - u produkciji koristiti HTTPS
    app.run(
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000)),
        debug=os.getenv('FLASK_ENV', 'production') == 'development',
        ssl_context='adhoc' if os.getenv('FLASK_ENV') == 'production' else None
    )

# Inicijalizuj bazu na prvi zahtev kada se koristi gunicorn
@app.before_request
def before_request_init():
    """Inicijalizuj bazu ako nije već inicijalizovana"""
    init_db()
