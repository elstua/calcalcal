#!/bin/bash

# Simple curl-based API tester for CalCalCal backend
# Alternative to Postman for quick testing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_URL="http://localhost:3000"
ACCESS_TOKEN=""
REFRESH_TOKEN=""
ENTRY_ID=""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_code=$4
    local description=$5
    
    echo -e "${BLUE}🧪 Testing: $description${NC}"
    
    local response_code
    local response_body
    
    if [ "$method" = "GET" ]; then
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" "$BASE_URL$endpoint")
        response_body=$(cat /tmp/response.json)
    else
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint")
        response_body=$(cat /tmp/response.json)
    fi
    
    if [ "$response_code" = "$expected_code" ]; then
        echo -e "${GREEN}✅ PASS${NC} (HTTP $response_code)"
        ((TESTS_PASSED++))
        
        # Extract tokens if this is auth endpoint
        if [[ "$endpoint" == *"signin-apple"* ]]; then
            ACCESS_TOKEN=$(echo "$response_body" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
            REFRESH_TOKEN=$(echo "$response_body" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)
            echo -e "${YELLOW}🔑 Tokens extracted${NC}"
        fi
        
        # Extract entry ID if this is create entry endpoint
        if [[ "$endpoint" == *"diary/entries"* && "$method" = "POST" ]]; then
            ENTRY_ID=$(echo "$response_body" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
            echo -e "${YELLOW}📝 Entry ID: $ENTRY_ID${NC}"
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (Expected HTTP $expected_code, got $response_code)"
        echo -e "${RED}Response: $response_body${NC}"
        ((TESTS_FAILED++))
    fi
    echo
}

test_auth_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_code=$4
    local description=$5
    local auth_header=$6
    
    echo -e "${BLUE}🧪 Testing: $description${NC}"
    
    local response_code
    local response_body
    
    if [ -n "$auth_header" ]; then
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $auth_header" \
            -d "$data" \
            "$BASE_URL$endpoint")
    else
        response_code=$(curl -s -o /tmp/response.json -w "%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint")
    fi
    
    response_body=$(cat /tmp/response.json)
    
    if [ "$response_code" = "$expected_code" ]; then
        echo -e "${GREEN}✅ PASS${NC} (HTTP $response_code)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC} (Expected HTTP $expected_code, got $response_code)"
        echo -e "${RED}Response: $response_body${NC}"
        ((TESTS_FAILED++))
    fi
    echo
}

# Main test execution
echo -e "${BLUE}🚀 Starting CalCalCal API Tests${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Check if backend is running
echo -e "${BLUE}🔍 Checking backend health...${NC}"
if ! curl -s "$BASE_URL/health" > /dev/null; then
    echo -e "${RED}❌ Backend is not running at $BASE_URL${NC}"
    echo -e "${YELLOW}💡 Start with: cd apps/backend/node && npm run dev${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Backend is healthy${NC}"
echo

# Test 1: Health Check
test_endpoint "GET" "/health" "" "200" "Health Check"

# Test 2: Apple Sign-In
test_endpoint "POST" "/api/auth/signin-apple" '{
  "identityToken": "test-token",
  "user": {
    "id": "com.apple.user.test123",
    "email": "test@example.com",
    "name": "Test User"
  }
}' "200" "Apple Sign-In"

# Test 3: Get Profile (with auth)
if [ -n "$ACCESS_TOKEN" ]; then
    test_auth_endpoint "GET" "/api/auth/profile" "" "200" "Get Profile" "$ACCESS_TOKEN"
else
    echo -e "${RED}❌ SKIP Get Profile (no access token)${NC}"
    ((TESTS_FAILED++))
fi

# Test 4: Create Diary Entry
if [ -n "$ACCESS_TOKEN" ]; then
    test_auth_endpoint "POST" "/api/diary/entries" '{
  "date": "2025-01-15",
  "content": "Had two eggs and toast for breakfast"
}' "201" "Create Diary Entry" "$ACCESS_TOKEN"
else
    echo -e "${RED}❌ SKIP Create Entry (no access token)${NC}"
    ((TESTS_FAILED++))
fi

# Test 5: Get Entry by ID
if [ -n "$ACCESS_TOKEN" ] && [ -n "$ENTRY_ID" ]; then
    test_auth_endpoint "GET" "/api/diary/entries/$ENTRY_ID" "" "200" "Get Entry by ID" "$ACCESS_TOKEN"
else
    echo -e "${RED}❌ SKIP Get Entry (no token or entry ID)${NC}"
    ((TESTS_FAILED++))
fi

# Test 6: List Entries
if [ -n "$ACCESS_TOKEN" ]; then
    test_auth_endpoint "GET" "/api/diary/entries?dateFrom=2025-01-01&dateTo=2025-01-31" "" "200" "List Entries" "$ACCESS_TOKEN"
else
    echo -e "${RED}❌ SKIP List Entries (no access token)${NC}"
    ((TESTS_FAILED++))
fi

# Test 7: Update Entry
if [ -n "$ACCESS_TOKEN" ] && [ -n "$ENTRY_ID" ]; then
    test_auth_endpoint "PATCH" "/api/diary/entries/$ENTRY_ID" '{
  "content": "Updated: Had two eggs and toast for breakfast"
}' "200" "Update Entry" "$ACCESS_TOKEN"
else
    echo -e "${RED}❌ SKIP Update Entry (no token or entry ID)${NC}"
    ((TESTS_FAILED++))
fi

# Test 8: Unauthorized Request
test_endpoint "GET" "/api/auth/profile" "" "401" "Unauthorized Request"

# Test 9: Invalid Token
test_auth_endpoint "GET" "/api/auth/profile" "" "401" "Invalid Token" "invalid-token"

# Test 10: Missing Required Fields
if [ -n "$ACCESS_TOKEN" ]; then
    test_auth_endpoint "POST" "/api/diary/entries" '{
  "content": "Missing date field"
}' "400" "Missing Required Fields" "$ACCESS_TOKEN"
else
    echo -e "${RED}❌ SKIP Missing Fields Test (no access token)${NC}"
    ((TESTS_FAILED++))
fi

# Cleanup: Delete test entry
if [ -n "$ACCESS_TOKEN" ] && [ -n "$ENTRY_ID" ]; then
    echo -e "${BLUE}🧹 Cleaning up test entry...${NC}"
    test_auth_endpoint "DELETE" "/api/diary/entries/$ENTRY_ID" "" "200" "Delete Entry" "$ACCESS_TOKEN"
fi

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}📊 Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✅ Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Tests Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}💥 Some tests failed${NC}"
    exit 1
fi