#!/bin/bash
set -euo pipefail

awslocal sqs get-queue-url --queue-name togglemaster-events >/dev/null 2>&1 || \
  awslocal sqs create-queue --queue-name togglemaster-events

awslocal dynamodb describe-table --table-name ToggleMasterAnalytics >/dev/null 2>&1 || \
  awslocal dynamodb create-table \
    --table-name ToggleMasterAnalytics \
    --attribute-definitions AttributeName=event_id,AttributeType=S \
    --key-schema AttributeName=event_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
