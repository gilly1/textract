#!/bin/bash
set -e

# Test individual Lambda functions
# Usage: ./test_lambda.sh <function_name> [payload_file]

FUNCTION_NAME="${1:-convert_to_image}"
PAYLOAD_FILE="${2:-test_payloads/${FUNCTION_NAME}_payload.json}"

# Get the function name with project prefix
PROJECT_PREFIX="document-processor"
FULL_FUNCTION_NAME="${PROJECT_PREFIX}-${FUNCTION_NAME}"

echo "🧪 Testing Lambda function: $FULL_FUNCTION_NAME"
echo "📄 Using payload file: $PAYLOAD_FILE"

if [[ ! -f "$PAYLOAD_FILE" ]]; then
    echo "❌ Payload file not found: $PAYLOAD_FILE"
    echo "Available payload files:"
    ls -la test_payloads/*.json
    exit 1
fi

echo ""
echo "📋 Payload content:"
cat "$PAYLOAD_FILE" | jq '.'

echo ""
echo "🚀 Invoking Lambda function..."

# Invoke the Lambda function
aws lambda invoke \
    --function-name "$FULL_FUNCTION_NAME" \
    --payload "file://$PAYLOAD_FILE" \
    --output json \
    response.json

echo ""
echo "📊 Lambda response:"
cat response.json | jq '.'

echo ""
echo "📄 Function output:"
if [[ -f "response.json" ]]; then
    # Try to decode the payload if it's base64 encoded
    PAYLOAD=$(cat response.json | jq -r '.Payload // empty')
    if [[ -n "$PAYLOAD" ]]; then
        echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
    fi
fi

# Clean up
rm -f response.json

echo ""
echo "✅ Lambda test completed!"
