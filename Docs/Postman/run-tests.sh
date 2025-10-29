#!/bin/bash

# CalCalCal Backend Test Runner
# This script runs automated tests against the backend API

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:3000"
TEST_USER_ID="com.apple.user.test123"
TEST_EMAIL="test@example.com"
TEST_NAME="Test User"
TEST_DATE="2025-01-15"

# Check if backend is running
echo -e "${BLUE}🔍 Checking if backend is running...${NC}"
if ! curl -s "$BASE_URL/health" > /dev/null; then
    echo -e "${RED}❌ Backend is not running at $BASE_URL${NC}"
    echo -e "${YELLOW}💡 Start the backend with: cd apps/backend/node && npm run dev${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Backend is running${NC}"

# Check if Newman is installed
if ! command -v newman &> /dev/null; then
    echo -e "${YELLOW}⚠️  Newman not found. Installing...${NC}"
    npm install -g newman
fi

# Run the tests
echo -e "${BLUE}🚀 Running API tests...${NC}"

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Run Newman tests
newman run "$SCRIPT_DIR/Calcalcal-API-Tests.postman_collection.json" \
    -e "$SCRIPT_DIR/Calcalcal.postman_environment.json" \
    --reporters cli,html \
    --reporter-html-export "$SCRIPT_DIR/test-report.html" \
    --timeout-request 10000

echo -e "${GREEN}✅ Tests completed!${NC}"
echo -e "${BLUE}📊 Test report saved to: $SCRIPT_DIR/test-report.html${NC}"

# Optional: Open the report
if command -v open &> /dev/null; then
    echo -e "${YELLOW}🔍 Opening test report...${NC}"
    open "$SCRIPT_DIR/test-report.html"
fi