#!/bin/bash

# Test script for PhoneGPT webhook server
# Usage: ./test_webhook.sh [webhook_url]

WEBHOOK_URL="${1:-https://phonegpt-webhook.systemd.diskstation.me}"

echo "🧪 Testing PhoneGPT Webhook Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Server: $WEBHOOK_URL"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Health Check
echo "1️⃣  Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$WEBHOOK_URL/health")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}❌ Health check failed${NC}"
    exit 1
fi
echo ""

# Test 2: Post Voice Input Event
echo "2️⃣  Testing webhook POST (voice_input)..."
WEBHOOK_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL/webhook" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "voice_input",
    "data": {"transcript": "What is the weather today?"},
    "device_id": "test_device_001"
  }')
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Webhook POST passed${NC}"
    echo "   Response: $WEBHOOK_RESPONSE"
else
    echo -e "${RED}❌ Webhook POST failed${NC}"
    exit 1
fi
echo ""

# Test 3: Post Gesture Event
echo "3️⃣  Testing webhook POST (gesture)..."
GESTURE_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL/webhook" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "gesture",
    "data": {"gesture_type": "tap_once"},
    "device_id": "test_device_001"
  }')
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Gesture event passed${NC}"
    echo "   Response: $GESTURE_RESPONSE"
else
    echo -e "${RED}❌ Gesture event failed${NC}"
    exit 1
fi
echo ""

# Test 4: Get Events
echo "4️⃣  Testing events polling..."
EVENTS_RESPONSE=$(curl -s "$WEBHOOK_URL/events?since=0")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Events polling passed${NC}"
    echo "   Response: $EVENTS_RESPONSE"
else
    echo -e "${RED}❌ Events polling failed${NC}"
    exit 1
fi
echo ""

# Test 5: Get Stats
echo "5️⃣  Testing stats endpoint..."
STATS_RESPONSE=$(curl -s "$WEBHOOK_URL/stats")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Stats endpoint passed${NC}"
    echo "   Response: $STATS_RESPONSE"
else
    echo -e "${RED}❌ Stats endpoint failed${NC}"
    exit 1
fi
echo ""

# Test 6: Display Request
echo "6️⃣  Testing display request..."
DISPLAY_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL/display" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Test response from PhoneGPT",
    "device_id": "test_device_001",
    "duration": 5
  }')
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Display request passed${NC}"
    echo "   Response: $DISPLAY_RESPONSE"
else
    echo -e "${RED}❌ Display request failed${NC}"
    exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy to Synology NAS (see DEPLOYMENT_SYNOLOGY.md)"
echo "2. Submit integration form to MentraOS"
echo "3. Test with real MentraOS app"
