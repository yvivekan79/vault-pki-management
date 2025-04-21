# Project Dependencies

This document lists all the required dependencies for running the Vault PKI Management Console.

## Python Dependencies

```
flask==2.3.2
flask-sqlalchemy==3.0.5
gunicorn==23.0.0
email-validator==2.0.0
psycopg2-binary==2.9.6
hvac==1.2.1
requests==2.31.0
python-dotenv==1.0.0
cryptography==41.0.3
Werkzeug==2.3.6
```

## System Dependencies

- Python 3.11 or later
- PostgreSQL (optional, SQLite can be used for development)
- HashiCorp Vault (for integration with actual Vault servers)
- SoftHSM2 (for PKCS#11 testing)

## Installing Dependencies

To install the Python dependencies, you can run:

```bash
pip install flask flask-sqlalchemy gunicorn email-validator psycopg2-binary hvac requests python-dotenv cryptography Werkzeug
```

Or, if you have a `requirements.txt` file:

```bash
pip install -r requirements.txt
```

For production deployments, it's recommended to use a virtual environment:

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```