#!/bin/bash

# ============================================
# Banking App API Test Script
# ============================================

set -e

API_URL="http://localhost"
ECHO_COLOR='\033[0;36m'
NC='\033[0m' # No Color

echo "Banking App - API Test Script"
echo "================================"
echo ""

# Check if API is available
echo -n "Checking if API is available... "
if ! curl -s "$API_URL/api/health" > /dev/null; then
    echo "NOT AVAILABLE"
    echo "Start the application with: ./scripts/setup.sh"
    exit 1
fi
echo "AVAILABLE"
echo ""

# Test 1: Health Check
echo -e "${ECHO_COLOR}[TEST 1] Health Check${NC}"
curl -s -X GET "$API_URL/api/health" | jq .
echo ""
echo ""

# Test 2: Register
echo -e "${ECHO_COLOR}[TEST 2] Register New User${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test_'$(date +%s)'@banking.local",
    "full_name": "Test User",
    "password": "testpass123"
  }')
echo "$REGISTER_RESPONSE" | jq .
USER_ID=$(echo "$REGISTER_RESPONSE" | jq -r '.user_id // empty')
echo ""
echo ""

# Test 3: Login
echo -e "${ECHO_COLOR}[TEST 3] Login${NC}"
LOGIN_EMAIL="admin@banking.local"
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'$LOGIN_EMAIL'",
    "password": "admin123"
  }')
echo "$LOGIN_RESPONSE" | jq .
TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
    echo "Login failed - no token"
    exit 1
fi
echo ""
echo ""

# Test 4: Get Health sa Token-om
echo -e "${ECHO_COLOR}[TEST 4] Health Check with Authentication${NC}"
curl -s -X GET "$API_URL/api/health" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""
echo ""

# Test 5: Create Account
echo -e "${ECHO_COLOR}[TEST 5] Create Account${NC}"
ADMIN_ID=$(curl -s -X GET "$API_URL/api/admin/users" \
  -H "Authorization: Bearer $TOKEN" | jq '.users[0].user_id')

CREATE_ACCOUNT_RESPONSE=$(curl -s -X POST "$API_URL/api/accounts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "account_type": "checking",
    "initial_balance": 5000
  }')
echo "$CREATE_ACCOUNT_RESPONSE" | jq .
ACCOUNT_ID=$(echo "$CREATE_ACCOUNT_RESPONSE" | jq -r '.account_id // empty')
echo ""
echo ""

if [ -z "$ACCOUNT_ID" ]; then
    echo "Cannot test transactions without an account"
    exit 0
fi

# Test 6: Get Account
echo -e "${ECHO_COLOR}[TEST 6] Get Account Details${NC}"
curl -s -X GET "$API_URL/api/accounts/$ACCOUNT_ID" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""
echo ""

# Test 7: Create Second Account for Transfer
echo -e "${ECHO_COLOR}[TEST 7] Create Second Account for Transfer${NC}"
SECOND_ACCOUNT_RESPONSE=$(curl -s -X POST "$API_URL/api/accounts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "account_type": "savings",
    "initial_balance": 1000
  }')
echo "$SECOND_ACCOUNT_RESPONSE" | jq .
SECOND_ACCOUNT_ID=$(echo "$SECOND_ACCOUNT_RESPONSE" | jq -r '.account_id // empty')
echo ""
echo ""

if [ ! -z "$SECOND_ACCOUNT_ID" ]; then
    # Test 8: Transfer Money
    echo -e "${ECHO_COLOR}[TEST 8] Transfer Money Between Accounts${NC}"
    curl -s -X POST "$API_URL/api/transactions/transfer" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{
        "from_account_id": '$ACCOUNT_ID',
        "to_account_id": '$SECOND_ACCOUNT_ID',
        "amount": 100,
        "description": "Test transfer"
      }' | jq .
    echo ""
    echo ""

    # Test 9: Get Transaction History
    echo -e "${ECHO_COLOR}[TEST 9] Get Transaction History${NC}"
    curl -s -X GET "$API_URL/api/transactions/$ACCOUNT_ID" \
      -H "Authorization: Bearer $TOKEN" | jq .
    echo ""
    echo ""
fi

# Test 10: Get Audit Log (Admin only)
echo -e "${ECHO_COLOR}[TEST 10] Get Audit Log (Admin Only)${NC}"
curl -s -X GET "$API_URL/api/admin/audit-log" \
  -H "Authorization: Bearer $TOKEN" | jq '.audit_logs | .[0:3]'
echo ""
echo ""

echo "Testing is complete!"
