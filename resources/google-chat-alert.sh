#!/bin/sh

echo "Sending Google Chat webhook: $1"

if [ -z "$GOOGLE_WEBHOOK_URL" ]; then
    echo "Error: GOOGLE_WEBHOOK_URL not set."
    exit 1
fi

if [ -z "$2" ]; then
    PAYLOAD='{"text": "'"$1"'"}'
else
    PAYLOAD='{"text": "'"$1"'```'"$(echo "$2" | sed 's/"/'\''/g')"'\```"}'
fi

if [ -n "$SLACK_PROXY" ]; then
    curl -s --proxy "$SLACK_PROXY" -X POST --data-raw "$PAYLOAD" "$GOOGLE_WEBHOOK_URL" --header 'Content-Type: application/json'
else
    curl -s -X POST --data-raw "$PAYLOAD" "$GOOGLE_WEBHOOK_URL" --header 'Content-Type: application/json'
fi