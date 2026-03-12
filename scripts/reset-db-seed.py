"""
Banking App - Database seed script.
Runs INSIDE the backend container via: docker exec -i banking_backend python < scripts/reset-db-seed.py
Creates accounts and transactions via the Flask API (needed for Fernet-encrypted balances).
Assumes users already exist in the database.
"""

import json
import time
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

API = "http://localhost:5000"


def api_call(method, path, token=None, data=None):
    """Make an API call to the Flask backend."""
    url = f"{API}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data else None
    req = Request(url, data=body, headers=headers, method=method)
    try:
        resp = urlopen(req)
        return json.loads(resp.read())
    except HTTPError as e:
        error_body = e.read().decode()
        print(f"  ERROR {e.code} on {method} {path}: {error_body}")
        return None


def login(email, password="admin123"):
    """Login and return JWT token."""
    result = api_call("POST", "/api/auth/login", data={"email": email, "password": password})
    if result and "token" in result:
        return result["token"]
    print(f"  FATAL: Could not login as {email}")
    return None


def create_accounts(token, accounts):
    """Create accounts for the logged-in user."""
    for acc in accounts:
        api_call("POST", "/api/accounts", token=token, data=acc)


def get_account_ids(token):
    """Get account IDs grouped by type."""
    result = api_call("GET", "/api/accounts", token=token)
    if not result or "accounts" not in result:
        return {}
    ids = {}
    for acc in result["accounts"]:
        ids[acc["account_type"]] = acc["account_id"]
    return ids


def main():
    print("[3/5] Creating accounts via API (encrypted balances)...")

    # Admin accounts
    token = login("admin@banking.local")
    if not token:
        return False
    create_accounts(token, [
        {"account_type": "checking", "initial_balance": 50000},
        {"account_type": "savings", "initial_balance": 100000},
    ])
    print("      Admin accounts created (checking: 50,000 RSD, savings: 100,000 RSD)")

    # Teller accounts
    token = login("teller@banking.local")
    if not token:
        return False
    create_accounts(token, [
        {"account_type": "checking", "initial_balance": 25000},
        {"account_type": "savings", "initial_balance": 75000},
    ])
    print("      Teller accounts created (checking: 25,000 RSD, savings: 75,000 RSD)")

    # Customer accounts
    token = login("customer@banking.local")
    if not token:
        return False
    create_accounts(token, [
        {"account_type": "checking", "initial_balance": 10000},
        {"account_type": "savings", "initial_balance": 30000},
    ])
    print("      Customer accounts created (checking: 10,000 RSD, savings: 30,000 RSD)")

    print("")
    print("[4/5] Creating sample transactions...")

    # Re-login as admin (JWT may have expired - 1 minute TTL)
    token = login("admin@banking.local")
    if not token:
        return False
    ids = get_account_ids(token)
    if "checking" in ids and "savings" in ids:
        api_call("POST", "/api/transactions/transfer", token=token, data={
            "from_account_id": ids["checking"],
            "to_account_id": ids["savings"],
            "amount": 5000,
            "description": "Monthly savings deposit",
        })
        api_call("POST", "/api/transactions/transfer", token=token, data={
            "from_account_id": ids["checking"],
            "to_account_id": ids["savings"],
            "amount": 2500,
            "description": "Emergency fund",
        })

    # Re-login as customer
    token = login("customer@banking.local")
    if not token:
        return False
    ids = get_account_ids(token)
    if "checking" in ids and "savings" in ids:
        api_call("POST", "/api/transactions/transfer", token=token, data={
            "from_account_id": ids["checking"],
            "to_account_id": ids["savings"],
            "amount": 1000,
            "description": "Weekly savings",
        })
        api_call("POST", "/api/transactions/transfer", token=token, data={
            "from_account_id": ids["savings"],
            "to_account_id": ids["checking"],
            "amount": 500,
            "description": "ATM withdrawal",
        })

    print("      Sample transactions created.")
    return True


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
