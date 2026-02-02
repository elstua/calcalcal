#!/bin/bash
#
# Setup Local Development Environment for CalCalCal
# This script configures the Xcode project to use environment-specific configurations
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 CalCalCal Local Development Setup${NC}"
echo ""

# Check if Xcode project exists
XCODE_PROJECT="$PROJECT_ROOT/Calycal.xcodeproj"
if [ ! -d "$XCODE_PROJECT" ]; then
    echo -e "${RED}❌ Error: Xcode project not found at $XCODE_PROJECT${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Checking xcconfig files...${NC}"

# Verify xcconfig files exist
XCCONFIG_DIR="$PROJECT_ROOT/xcconfigs"
for config in Debug Release Staging; do
    if [ -f "$XCCONFIG_DIR/$config.xcconfig" ]; then
        echo -e "${GREEN}  ✓ $config.xcconfig${NC}"
    else
        echo -e "${RED}  ✗ $config.xcconfig missing${NC}"
    fi
done

echo ""
echo -e "${YELLOW}⚠️  Manual Xcode Configuration Required${NC}"
echo ""
echo "The xcconfig files have been created, but you need to configure Xcode to use them:"
echo ""
echo "1. Open Calycal.xcodeproj in Xcode"
echo ""
echo "2. Select the project in the navigator (blue icon)"
echo ""
echo "3. Go to the 'Info' tab (Project, not Target)"
echo ""
echo "4. Under 'Configurations', expand Debug and Release:"
echo "   - Debug: Set to 'xcconfigs/Debug.xcconfig'"
echo "   - Release: Set to 'xcconfigs/Release.xcconfig'"
echo ""
echo "   To add a Staging configuration:"
echo "   - Click '+' > Duplicate 'Release' Configuration"
echo "   - Name it 'Staging'"
echo "   - Set to 'xcconfigs/Staging.xcconfig'"
echo ""
echo "5. Verify the setup:"
echo "   - Select your target"
echo "   - Go to Build Settings > Info.plist Values"
echo "   - Check that API_URL shows the correct value for each configuration"
echo ""

# Check if backend dev files exist
echo -e "${BLUE}📦 Checking backend development files...${NC}"
BACKEND_DIR="$PROJECT_ROOT/apps/backend/node"

if [ -f "$BACKEND_DIR/docker-compose.dev.yml" ]; then
    echo -e "${GREEN}  ✓ docker-compose.dev.yml${NC}"
else
    echo -e "${RED}  ✗ docker-compose.dev.yml missing${NC}"
fi

if [ -f "$BACKEND_DIR/Dockerfile.dev" ]; then
    echo -e "${GREEN}  ✓ Dockerfile.dev${NC}"
else
    echo -e "${RED}  ✗ Dockerfile.dev missing${NC}"
fi

echo ""
echo -e "${YELLOW}🐳 To start the local backend:${NC}"
echo ""
echo "   cd apps/backend/node"
echo "   docker-compose -f docker-compose.dev.yml up -d"
echo ""
echo "   This will start:"
echo "   - PostgreSQL on port 5432"
echo "   - API server on port 3000"
echo ""
echo "   Run migrations:"
echo "   npm run migrate:dev"
echo ""

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure Xcode with the xcconfig files (see instructions above)"
echo "2. Start the local backend"
echo "3. Build and run the app in Debug mode"
echo ""
echo "The app will automatically connect to:"
echo "  - Debug builds: http://localhost:3000"
echo "  - Release builds: https://api.calcalcal.app"
echo ""
