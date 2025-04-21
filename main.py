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
@app.route('/api/v1/certificates', methods=['GET'])
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
            'status': cert.status,
            'created_at': cert.created_at.isoformat() if cert.created_at else None
        })
    return jsonify(certificates=result)

@app.route('/api/v1/certificates/<int:certificate_id>', methods=['GET'])
def get_certificate(certificate_id):
    cert = Certificate.query.get_or_404(certificate_id)
    return jsonify({
        'id': cert.id,
        'name': cert.name,
        'common_name': cert.common_name,
        'issuer': cert.issuer,
        'valid_from': cert.valid_from.isoformat(),
        'valid_until': cert.valid_until.isoformat(),
        'status': cert.status,
        'created_at': cert.created_at.isoformat() if cert.created_at else None
    })

@app.route('/api/v1/certificates/issue', methods=['POST'])
def issue_certificate():
    data = request.json
    
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
    required_fields = ['common_name', 'ttl', 'role']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'Missing required field: {field}'}), 400
    
    # In a real implementation, this would call the Vault API to issue a certificate
    # For now, we'll simulate it by creating a record in our database
    from datetime import datetime, timedelta
    
    # Parse TTL (assumed format like "8760h" for 1 year)
    ttl_str = data.get('ttl', '8760h')
    ttl_value = int(ttl_str.rstrip('h'))
    ttl_hours = ttl_value
    
    # Create a new certificate record
    now = datetime.now()
    new_cert = Certificate(
        name=data.get('name', f"{data['common_name'].replace('.', '-')}-{now.strftime('%Y%m%d')}"),
        common_name=data['common_name'],
        issuer="Vault Intermediate CA",
        valid_from=now,
        valid_until=now + timedelta(hours=ttl_hours),
        status="valid"
    )
    
    db.session.add(new_cert)
    db.session.commit()
    
    # In a real implementation, this would return the actual certificate data
    return jsonify({
        'success': True,
        'certificate_id': new_cert.id,
        'certificate': {
            'id': new_cert.id,
            'name': new_cert.name,
            'common_name': new_cert.common_name,
            'issuer': new_cert.issuer,
            'valid_from': new_cert.valid_from.isoformat(),
            'valid_until': new_cert.valid_until.isoformat(),
            'status': new_cert.status
        },
        'message': 'Certificate issued successfully. In a production environment, this would return the actual certificate data.'
    }), 201

@app.route('/api/v1/certificates/<int:certificate_id>/revoke', methods=['POST'])
def revoke_certificate(certificate_id):
    cert = Certificate.query.get_or_404(certificate_id)
    
    # In a real implementation, this would call the Vault API to revoke the certificate
    # For now, we'll simulate it by updating the record in our database
    cert.status = "revoked"
    db.session.commit()
    
    return jsonify({
        'success': True,
        'certificate_id': cert.id,
        'status': 'revoked',
        'message': 'Certificate revoked successfully'
    })

@app.route('/api/v1/servers', methods=['GET'])
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
            'version': server.version,
            'last_checked': server.last_checked.isoformat() if server.last_checked else None
        })
    return jsonify(servers=result)

@app.route('/api/v1/servers/<int:server_id>', methods=['GET'])
def get_server(server_id):
    server = VaultServer.query.get_or_404(server_id)
    return jsonify({
        'id': server.id,
        'name': server.name,
        'address': server.address,
        'status': server.status,
        'sealed': server.sealed,
        'version': server.version,
        'last_checked': server.last_checked.isoformat() if server.last_checked else None
    })

@app.route('/api/v1/servers/<int:server_id>/unseal', methods=['POST'])
def unseal_server(server_id):
    server = VaultServer.query.get_or_404(server_id)
    
    # In a real implementation, this would call the Vault API to unseal the server
    # For now, we'll simulate it by updating the record in our database
    if not server.sealed:
        return jsonify({
            'success': False,
            'message': 'Server is already unsealed'
        }), 400
    
    server.sealed = False
    db.session.commit()
    
    return jsonify({
        'success': True,
        'server_id': server.id,
        'sealed': False,
        'message': 'Server unsealed successfully'
    })

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