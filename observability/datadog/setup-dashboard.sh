#!/bin/bash
set -e

# Setup script for Temporal SDK DataDog Dashboard
# This script:
# 1. Loads the Temporal SDK dashboard from ./dashboards/temporal-core-sdk.json
# 2. Uploads it to your DataDog account using the DataDog API
# 3. Provides instructions for enabling percentiles for distribution metrics

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Temporal DataDog Dashboard Setup ===${NC}\n"

# Load environment variables
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please copy .env.sample to .env and configure your DataDog credentials"
    exit 1
fi

source .env

# Check required variables
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ] || [ -z "$DD_SITE" ]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Please ensure DD_API_KEY, DD_APP_KEY, and DD_SITE are set in .env"
    exit 1
fi

# Set DataDog API endpoint based on site
case "$DD_SITE" in
    "datadoghq.com")
        DD_API_URL="https://api.datadoghq.com/api/v1"
        ;;
    "datadoghq.eu")
        DD_API_URL="https://api.datadoghq.eu/api/v1"
        ;;
    "us3.datadoghq.com")
        DD_API_URL="https://api.us3.datadoghq.com/api/v1"
        ;;
    "us5.datadoghq.com")
        DD_API_URL="https://api.us5.datadoghq.com/api/v1"
        ;;
    "ap1.datadoghq.com")
        DD_API_URL="https://api.ap1.datadoghq.com/api/v1"
        ;;
    *)
        echo -e "${RED}Error: Unknown DD_SITE: $DD_SITE${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Step 1: Loading Temporal SDK Dashboard...${NC}"
DASHBOARD_FILE="./dashboards/temporal-core-sdk.json"

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo -e "${RED}Error: Dashboard file not found at $DASHBOARD_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dashboard file loaded${NC}\n"

echo -e "${YELLOW}Step 2: Uploading dashboard to DataDog...${NC}"

RESPONSE=$(curl -s -X POST "$DD_API_URL/dashboard" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
  -d @"$DASHBOARD_FILE")

if echo "$RESPONSE" | grep -q "\"id\""; then
    DASHBOARD_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    DASHBOARD_URL_PATH=$(echo "$RESPONSE" | grep -o '"url":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Dashboard created successfully!${NC}"
    echo -e "Dashboard ID: $DASHBOARD_ID"
    echo -e "Dashboard URL: https://app.$DD_SITE$DASHBOARD_URL_PATH\n"
else
    echo -e "${RED}Error: Failed to create dashboard${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

echo -e "${YELLOW}Step 3: Enabling percentiles for distribution metrics...${NC}"
echo -e "${YELLOW}This requires metrics to exist first, so you may need to run this again after your worker has been running for a few minutes.${NC}\n"

# List of metrics that need percentiles enabled
METRICS=(
    "temporal.request.latency"
    "temporal.long.request.latency"
    "temporal.workflow.task.schedule.to.start.latency"
    "temporal.workflow.endtoend.latency"
    "temporal.activity.schedule.to.start.latency"
    "temporal.activity.execution.latency"
    "temporal.activity.succeed.endtoend.latency"
    "temporal.local.activity.execution.latency"
    "temporal.local.activity.succeeded.endtoend.latency"
)

# Note: DataDog API doesn't provide a direct way to enable percentiles via API
# Users must do this manually in the UI or wait for metrics to auto-configure

echo -e "${YELLOW}⚠ Important: Percentiles must be enabled manually for the following metrics:${NC}\n"

for metric in "${METRICS[@]}"; do
    echo "  • $metric"
done

echo -e "\n${YELLOW}To enable percentiles:${NC}"
echo "1. Go to https://app.$DD_SITE/metric/summary"
echo "2. Search for each metric above"
echo "3. Click the metric → Advanced → Percentiles → Configure"
echo "4. Enable p50, p75, p95, p99"
echo ""
echo -e "${YELLOW}Alternatively, these will auto-enable after metrics start flowing (may take 15-30 minutes)${NC}\n"

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "Your Temporal SDK Dashboard is ready at:"
echo -e "${GREEN}https://app.$DD_SITE$DASHBOARD_URL_PATH${NC}\n"
echo -e "Note: The dashboard will show data once:"
echo "  1. Your Temporal worker is running and exposing metrics"
echo "  2. The DataDog agent has collected metrics for a few minutes"
echo "  3. Percentiles are enabled for distribution metrics"