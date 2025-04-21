import os
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_sqlalchemy import SQLAlchemy

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key")

# Configure SQLAlchemy
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get("DATABASE_URL", "sqlite:///vault_pki.db")
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Initialize SQLAlchemy
db = SQLAlchemy(app)

# Define models
class Certificate(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    common_name = db.Column(db.String(255), nullable=False)
    issuer = db.Column(db.String(255), nullable=False)
    valid_from = db.Column(db.DateTime, nullable=False)
    valid_until = db.Column(db.DateTime, nullable=False)
    status = db.Column(db.String(50), nullable=False)
    
class VaultServer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    address = db.Column(db.String(255), nullable=False)
    status = db.Column(db.String(50), nullable=False)
    sealed = db.Column(db.Boolean, default=True)
    version = db.Column(db.String(50))
    
# Create tables
with app.app_context():
    db.create_all()

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

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

# Template for demonstration purposes
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)