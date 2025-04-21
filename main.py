import os
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase

# Create a base class for SQLAlchemy models
class Base(DeclarativeBase):
    pass

# Initialize SQLAlchemy with the base class
db = SQLAlchemy(model_class=Base)

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key")

# Configure SQLAlchemy to use PostgreSQL
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL")
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
    "pool_recycle": 300,
    "pool_pre_ping": True,
}

# Initialize the app with SQLAlchemy
db.init_app(app)

# Define models
class Certificate(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    common_name = db.Column(db.String(255), nullable=False)
    issuer = db.Column(db.String(255), nullable=False)
    valid_from = db.Column(db.DateTime, nullable=False)
    valid_until = db.Column(db.DateTime, nullable=False)
    status = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    
class VaultServer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    address = db.Column(db.String(255), nullable=False)
    status = db.Column(db.String(50), nullable=False)
    sealed = db.Column(db.Boolean, default=True)
    version = db.Column(db.String(50))
    last_checked = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

# Create database tables
with app.app_context():
    db.create_all()

# Seed function to add sample data if database is empty
def seed_sample_data():
    from datetime import datetime, timedelta
    
    # Only seed if there's no data
    if not Certificate.query.first() and not VaultServer.query.first():
        # Add sample vault servers
        servers = [
            VaultServer(
                name="vault-0",
                address="vault-0.vault-internal:8200",
                status="healthy",
                sealed=False,
                version="1.14.0"
            ),
            VaultServer(
                name="vault-1",
                address="vault-1.vault-internal:8200",
                status="healthy",
                sealed=False,
                version="1.14.0"
            ),
            VaultServer(
                name="vault-2",
                address="vault-2.vault-internal:8200",
                status="healthy",
                sealed=False,
                version="1.14.0"
            )
        ]
        db.session.add_all(servers)
        
        # Add sample certificates
        now = datetime.now()
        certificates = [
            Certificate(
                name="root-ca",
                common_name="Vault Root CA",
                issuer="Self",
                valid_from=now - timedelta(days=30),
                valid_until=now + timedelta(days=3650),
                status="valid"
            ),
            Certificate(
                name="intermediate-ca",
                common_name="Vault Intermediate CA",
                issuer="Vault Root CA",
                valid_from=now - timedelta(days=15),
                valid_until=now + timedelta(days=1825),
                status="valid"
            ),
            Certificate(
                name="api-example-com",
                common_name="api.example.com",
                issuer="Vault Intermediate CA",
                valid_from=now - timedelta(days=5),
                valid_until=now + timedelta(days=365),
                status="valid"
            ),
            Certificate(
                name="expiring-cert",
                common_name="expiring.example.com",
                issuer="Vault Intermediate CA",
                valid_from=now - timedelta(days=350),
                valid_until=now + timedelta(days=15),
                status="expiring"
            )
        ]
        db.session.add_all(certificates)
        db.session.commit()
        print("Database seeded with sample data")

# Routes
@app.route('/')
def index():
    return render_template('index.html', 
                          vault_servers=VaultServer.query.all(),
                          certificates=Certificate.query.all())

@app.route('/certificates')
def list_certificates():
    certificates = Certificate.query.all()
    return render_template('certificates.html', certificates=certificates)

@app.route('/servers')
def list_servers():
    servers = VaultServer.query.all()
    return render_template('servers.html', servers=servers)

# API routes
@app.route('/api/certificates', methods=['GET'])
def api_certificates():
    certs = Certificate.query.all()
    result = []
    for cert in certs:
        result.append({
            'id': cert.id,
            'name': cert.name,
            'common_name': cert.common_name,
            'issuer': cert.issuer,
            'valid_from': cert.valid_from.isoformat(),
            'valid_until': cert.valid_until.isoformat(),
            'status': cert.status
        })
    return jsonify(certificates=result)

@app.route('/api/servers', methods=['GET'])
def api_servers():
    servers = VaultServer.query.all()
    result = []
    for server in servers:
        result.append({
            'id': server.id,
            'name': server.name,
            'address': server.address,
            'status': server.status,
            'sealed': server.sealed,
            'version': server.version
        })
    return jsonify(servers=result)

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

# Template for documentation
@app.route('/api/documentation')
def api_docs():
    return render_template('api_docs.html')

# Error handling
@app.errorhandler(404)
def page_not_found(e):
    return render_template('error.html', error=e), 404

@app.errorhandler(500)
def server_error(e):
    return render_template('error.html', error=e), 500

# Call the seed function when the application starts
with app.app_context():
    seed_sample_data()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)