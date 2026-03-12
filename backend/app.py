"""
Banking system with encryption and RBAC access control
Open Source solution with Flask, PostgreSQL and TLS/SSL
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

# Application configuration
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://user:pass@localhost/banking_db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JSON_SORT_KEYS'] = False
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'super-secret-key-change-in-production')
app.config['JWT_EXPIRATION_DELTA'] = timedelta(minutes=3)
app.config['JWT_ALGORITHM'] = 'HS256'

# Initialize extensions
db.init_app(app)

# CORS configuration
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

# ============= HELPER FUNCTIONS =============

def generate_token(user_id, role):
    """Generate JWT token"""
    payload = {
        'user_id': user_id,
        'role': role,
        'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA'],
        'iat': datetime.utcnow()
    }
    token = jwt.encode(payload, app.config['SECRET_KEY'], algorithm=app.config['JWT_ALGORITHM'])
    return token

def verify_token(token):
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=[app.config['JWT_ALGORITHM']])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def require_auth(allowed_roles=None):
    """Decorator for requiring authentication and role verification"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            # Extract token from Authorization header
            auth_header = request.headers.get('Authorization', '')
            if not auth_header.startswith('Bearer '):
                return {'error': 'Authentication required'}, 401
            
            token = auth_header.split(' ', 1)[1]
            payload = verify_token(token)
            if not payload:
                return {'error': 'Invalid token'}, 401
            
            if allowed_roles and payload['role'] not in allowed_roles:
                logger.warning(f"Access denied: user {payload['user_id']} with role {payload['role']}")
                return {'error': 'Access denied'}, 403
            
            request.user_id = payload['user_id']
            request.user_role = payload['role']
            return f(*args, **kwargs)
        return decorated
    return decorator

def log_action(action, details, user_id, status='success'):
    """Log all actions for audit"""
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
    """Register new user"""
    try:
        data = request.get_json()
        
        if User.query.filter_by(email=data['email']).first():
            return {'error': 'Email already exists'}, 400
        
        user = User(
            email=data['email'],
            full_name=data['full_name'],
            role=data.get('role', 'customer')  # customer, teller, admin
        )
        user.set_password(data['password'])
        
        db.session.add(user)
        db.session.commit()
        
        log_action('REGISTER', f"New user: {data['email']}", user.id)
        
        return {
            'message': 'Registration successful',
            'user_id': user.id
        }, 201
        
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return {'error': 'Registration error'}, 500

@app.route('/api/auth/login', methods=['POST', 'OPTIONS'])
@limiter.limit("10 per hour")
def login():
    """User login"""
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        if not data or 'email' not in data or 'password' not in data:
            return {'error': 'Email and password are required'}, 400
        
        email = data.get('email', '').lower()
        password = data.get('password', '')
        
        user = User.query.filter_by(email=email).first()
        
        if not user:
            logger.warning(f"User with email {email} not found")
            log_action('LOGIN_FAILED', f"User not found: {email}", None, 'failed')
            return {'error': 'Invalid email or password'}, 401
        
        if not user.check_password(password):
            logger.warning(f"Wrong password for user {email}")
            log_action('LOGIN_FAILED', f"Wrong password: {email}", user.id, 'failed')
            return {'error': 'Invalid email or password'}, 401
        
        token = generate_token(user.id, user.role)
        log_action('LOGIN', f"Login: {email}", user.id)
        
        return {
            'token': token,
            'user_id': user.id,
            'role': user.role,
            'full_name': user.full_name
        }, 200
        
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return {'error': 'Login error'}, 500

@app.route('/api/auth/refresh', methods=['POST'])
def refresh_token():
    """Refresh JWT token before expiry"""
    try:
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return {'error': 'Token required'}, 401

        token = auth_header.split(' ', 1)[1]
        try:
            # Accept tokens that expired within the last 5 minutes
            payload = jwt.decode(
                token, app.config['SECRET_KEY'],
                algorithms=[app.config['JWT_ALGORITHM']],
                options={'verify_exp': False}
            )
        except jwt.InvalidTokenError:
            return {'error': 'Invalid token'}, 401

        # Check that token is not older than 24h (abuse protection)
        iat = datetime.utcfromtimestamp(payload.get('iat', 0))
        if (datetime.utcnow() - iat).total_seconds() > 86400:
            return {'error': 'Token is too old for renewal'}, 401

        new_token = generate_token(payload['user_id'], payload['role'])
        log_action('TOKEN_REFRESH', f"Token renewal for user {payload['user_id']}", payload['user_id'])

        return {'token': new_token}, 200

    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return {'error': 'Token refresh error'}, 500

# ============= ACCOUNT ENDPOINTS =============

@app.route('/api/accounts', methods=['GET'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def list_accounts():
    """Get all user accounts"""
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
        logger.error(f"Error fetching accounts: {str(e)}")
        return {'error': 'Error fetching accounts'}, 500

@app.route('/api/accounts', methods=['POST'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def create_account():
    """Create new account"""
    try:
        data = request.get_json()
        
        # Only admin can create account for others, customer only for themselves
        user_id = data.get('user_id', request.user_id)
        if request.user_role != 'admin' and user_id != request.user_id:
            return {'error': 'Access denied'}, 403
        
        account = Account(
            user_id=user_id,
            account_number=Account.generate_account_number(),
            account_type=data.get('account_type', 'checking'),  # checking, savings
            balance=data.get('initial_balance', 0)
        )
        
        db.session.add(account)
        db.session.commit()
        
        log_action('CREATE_ACCOUNT', f"New account: {account.account_number}", request.user_id)
        
        return {
            'account_id': account.id,
            'account_number': account.account_number,
            'balance': account.balance
        }, 201
        
    except Exception as e:
        logger.error(f"Error creating account: {str(e)}")
        return {'error': 'Error creating account'}, 500

@app.route('/api/accounts/<int:account_id>', methods=['GET'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def get_account(account_id):
    """Get account details"""
    try:
        account = Account.query.get(account_id)
        
        if not account:
            return {'error': 'Account not found'}, 404
        
        # Permission check
        if request.user_role == 'customer' and account.user_id != request.user_id:
            return {'error': 'Access denied to this account'}, 403
        
        return {
            'account_id': account.id,
            'account_number': account.account_number,
            'account_type': account.account_type,
            'balance': account.balance,
            'created_at': account.created_at.isoformat()
        }, 200
        
    except Exception as e:
        logger.error(f"Error fetching account: {str(e)}")
        return {'error': 'Error fetching account'}, 500

# ============= TRANSACTION ENDPOINTS =============

@app.route('/api/transactions/transfer', methods=['POST'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
@limiter.limit("20 per hour")
def transfer():
    """Transfer money between accounts"""
    try:
        data = request.get_json()
        
        from_account = Account.query.get(data['from_account_id'])
        to_account = Account.query.get(data['to_account_id'])
        amount = float(data['amount'])
        
        if not from_account or not to_account:
            return {'error': 'Account not found'}, 404
        
        # RBAC check — teller and customer can only transfer from their own accounts
        if request.user_role in ('customer', 'teller') and from_account.user_id != request.user_id:
            log_action('TRANSFER_DENIED', f"Unauthorized transfer attempt", request.user_id, 'failed')
            return {'error': 'Access denied to this account'}, 403
        
        if amount <= 0:
            return {'error': 'Amount must be greater than 0'}, 400
        
        if from_account.balance < amount:
            return {'error': 'Insufficient funds'}, 400
        
        # Execute transfer
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
        
        log_action('TRANSFER', f"Transfer: {amount} from {from_account.account_number} to {to_account.account_number}", request.user_id)
        
        return {
            'transaction_id': transaction.id,
            'status': 'completed',
            'amount': amount,
            'timestamp': transaction.created_at.isoformat()
        }, 200
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Transfer error: {str(e)}")
        return {'error': 'Transfer error'}, 500

@app.route('/api/transactions/<int:account_id>', methods=['GET'])
@require_auth(allowed_roles=['customer', 'teller', 'admin'])
def get_transactions(account_id):
    """Get transaction history"""
    try:
        account = Account.query.get(account_id)
        
        if not account:
            return {'error': 'Account not found'}, 404
        
        # RBAC check
        if request.user_role == 'customer' and account.user_id != request.user_id:
            return {'error': 'Access denied to this account'}, 403
        
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
        logger.error(f"Error fetching transactions: {str(e)}")
        return {'error': 'Error fetching transactions'}, 500

# ============= ADMIN ENDPOINTS =============

@app.route('/api/admin/audit-log', methods=['GET'])
@require_auth(allowed_roles=['admin'])
def get_audit_log():
    """Get audit log (admin only)"""
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
        logger.error(f"Error fetching audit log: {str(e)}")
        return {'error': 'Error fetching audit log'}, 500

@app.route('/api/admin/users', methods=['GET'])
@require_auth(allowed_roles=['admin'])
def get_users():
    """Get all users (admin only)"""
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
        logger.error(f"Error fetching users: {str(e)}")
        return {'error': 'Error fetching users'}, 500

# ============= ERROR HANDLERS =============

@app.errorhandler(400)
def bad_request(error):
    return {'error': 'Bad request'}, 400

@app.errorhandler(401)
def unauthorized(error):
    return {'error': 'Unauthorized'}, 401

@app.errorhandler(403)
def forbidden(error):
    return {'error': 'Access denied'}, 403

@app.errorhandler(404)
def not_found(error):
    return {'error': 'Not found'}, 404

@app.errorhandler(429)
def ratelimit_handler(e):
    return {'error': 'Too many requests - try again later'}, 429

@app.errorhandler(500)
def internal_error(error):
    return {'error': 'Internal server error'}, 500

# ============= HEALTH CHECK =============

@app.route('/api/health', methods=['GET'])
def health():
    """Application health check"""
    return {'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}, 200

@app.route('/api/debug/users', methods=['GET'])
def debug_users():
    """Debug endpoint - show all users (DEVELOPMENT ONLY)"""
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
        logger.error(f"Debug query error: {str(e)}")
        return {'error': str(e)}, 500

# ============= DB INITIALIZATION =============

_db_initialized = False

def init_db():
    """Initialize database (idempotent - safe for multiple calls)"""
    global _db_initialized
    
    if _db_initialized:
        return
    
    try:
        with app.app_context():
            # Check if tables exist before creating new ones
            inspector = __import__('sqlalchemy').inspect(db.engine)
            tables = inspector.get_table_names()
            
            if not tables:
                logger.info("Creating tables...")
                db.create_all()
                logger.info("Database initialized")
            else:
                logger.info(f"Database already initialized ({len(tables)} tables)")
            
            _db_initialized = True
    except Exception as e:
        logger.error(f"Database initialization error: {str(e)}")
        _db_initialized = True

if __name__ == '__main__':
    init_db()
    
    # Development with HTTP - in production use HTTPS
    app.run(
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000)),
        debug=os.getenv('FLASK_ENV', 'production') == 'development',
        ssl_context='adhoc' if os.getenv('FLASK_ENV') == 'production' else None
    )

# Initialize database on first request when using gunicorn
@app.before_request
def before_request_init():
    """Initialize database if not already initialized"""
    init_db()
