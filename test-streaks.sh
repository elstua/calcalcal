#!/bin/bash

# Streaks Testing Script
# Quick way to test streaks functionality

set -e

BASE_URL="http://localhost:3000"
JWT_TOKEN=""
USER_ID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔥 CalCalCal Streaks Testing Script${NC}"
echo "=================================="

# Function to make API requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local auth=$4
    
    local cmd="curl -s -w '\n%{http_code}'"
    
    if [ "$method" = "POST" ] || [ "$method" = "PUT" ] || [ "$method" = "PATCH" ]; then
        cmd="$cmd -X $method"
    fi
    
    if [ -n "$data" ]; then
        cmd="$cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    if [ -n "$auth" ] && [ -n "$JWT_TOKEN" ]; then
        cmd="$cmd -H 'Authorization: Bearer $JWT_TOKEN'"
    fi
    
    cmd="$cmd '$BASE_URL$endpoint'"
    
    local response=$(eval $cmd)
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    echo "$body"
    return $http_code
}

# Function to check server health
check_server() {
    echo -e "${YELLOW}📡 Checking server health...${NC}"
    
    local response=$(make_request "GET" "/health")
    local status=$?
    
    if [ $status -eq 200 ]; then
        echo -e "${GREEN}✅ Server is running${NC}"
        return 0
    else
        echo -e "${RED}❌ Server is not responding (status: $status)${NC}"
        echo "Please start the server with: cd apps/backend/node && npm run dev"
        exit 1
    fi
}

# Function to create test user
create_user() {
    echo -e "${YELLOW}👤 Creating test user...${NC}"
    
    local device_id="test-device-$(date +%s)"
    local data="{\"deviceId\":\"$device_id\"}"
    
    local response=$(make_request "POST" "/api/auth/create-temporary" "$data" "false")
    local status=$?
    
    if [ $status -eq 200 ]; then
        JWT_TOKEN=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
        USER_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        
        echo -e "${GREEN}✅ User created successfully${NC}"
        echo "   User ID: $USER_ID"
        echo "   Token: ${JWT_TOKEN:0:20}..."
        return 0
    else
        echo -e "${RED}❌ Failed to create user${NC}"
        echo "Response: $response"
        exit 1
    fi
}

# Function to get current streaks
get_streaks() {
    echo -e "${YELLOW}📊 Getting current streaks...${NC}"
    
    local response=$(make_request "GET" "/api/streaks" "" "true")
    local status=$?
    
    if [ $status -eq 200 ]; then
        echo -e "${GREEN}✅ Current streaks:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        return 0
    else
        echo -e "${RED}❌ Failed to get streaks (status: $status)${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Function to create diary entry
create_entry() {
    local date=$1
    local content=$2
    
    echo -e "${YELLOW}📝 Creating diary entry for $date...${NC}"
    
    local data="{\"date\":\"$date\",\"content\":\"$content\",\"blocks\":[],\"total_calories\":500}"
    
    local response=$(make_request "POST" "/api/diary/entries" "$data" "true")
    local status=$?
    
    if [ $status -eq 201 ]; then
        echo -e "${GREEN}✅ Entry created for $date${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create entry for $date (status: $status)${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Function to test consecutive streak
test_consecutive_streak() {
    echo -e "\n${BLUE}🧪 Testing 5-day consecutive streak...${NC}"
    
    # Create entries for 5 consecutive days
    for i in {4..0}; do
        local date=$(date -d "$i days ago" +%Y-%m-%d)
        local day_num=$((5-i))
        local content="Healthy eating day $day_num. Had salad and grilled chicken for lunch."
        
        create_entry "$date" "$content"
        sleep 0.5
    done
    
    echo -e "\n${YELLOW}📊 Checking streaks after consecutive entries...${NC}"
    get_streaks
}

# Function to test streak break
test_streak_break() {
    echo -e "\n${BLUE}🧪 Testing streak break...${NC}"
    
    # Create entry with placeholder content (should not count)
    local yesterday=$(date -d "1 day ago" +%Y-%m-%d)
    create_entry "$yesterday" "What did you eat today?"
    
    echo -e "\n${YELLOW}📊 Checking streaks after placeholder entry...${NC}"
    get_streaks
}

# Function to test recalculation
test_recalculation() {
    echo -e "\n${BLUE}🧪 Testing streak recalculation...${NC}"
    
    local response=$(make_request "POST" "/api/streaks/recalculate" "" "true")
    local status=$?
    
    if [ $status -eq 200 ]; then
        echo -e "${GREEN}✅ Recalculation completed:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        return 0
    else
        echo -e "${RED}❌ Failed to recalculate (status: $status)${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Function to test streak history
test_history() {
    echo -e "\n${BLUE}🧪 Testing streak history...${NC}"
    
    local response=$(make_request "GET" "/api/streaks/history" "" "true")
    local status=$?
    
    if [ $status -eq 200 ]; then
        echo -e "${GREEN}✅ Streak history:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        return 0
    else
        echo -e "${RED}❌ Failed to get history (status: $status)${NC}"
        return 1
    fi
}

# Function to cleanup test data
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up test data...${NC}"
    
    if [ -n "$JWT_TOKEN" ]; then
        local response=$(make_request "DELETE" "/api/auth/delete-account" "" "true")
        local status=$?
        
        if [ $status -eq 200 ]; then
            echo -e "${GREEN}✅ Test user deleted successfully${NC}"
        else
            echo -e "${RED}⚠️  Failed to delete test user${NC}"
        fi
    fi
}

# Function to run automated tests
run_automated_tests() {
    echo -e "\n${BLUE}🤖 Running automated tests...${NC}"
    
    cd apps/backend/node
    
    if npm test -- streaks.test.ts; then
        echo -e "${GREEN}✅ All automated tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some automated tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    local test_type=${1:-"manual"}
    
    case $test_type in
        "manual")
            check_server
            create_user
            get_streaks
            test_consecutive_streak
            test_streak_break
            test_recalculation
            test_history
            cleanup
            ;;
        "automated")
            run_automated_tests
            ;;
        "quick")
            check_server
            create_user
            get_streaks
            test_consecutive_streak
            get_streaks
            cleanup
            ;;
        *)
            echo "Usage: $0 [manual|automated|quick]"
            echo "  manual    - Run full manual test suite (default)"
            echo "  automated - Run automated test suite"
            echo "  quick     - Run quick manual test"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}🎉 Testing completed!${NC}"
}

# Trap to cleanup on exit
trap cleanup EXIT

# Run main function with all arguments
main "$@"