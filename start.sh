#!/bin/bash
set -e

# Start PaddleX on internal-only port in background
paddlex --serve \
  --pipeline /app/pipeline_config.yaml \
  --device cpu \
  --host 127.0.0.1 \
  --port 8080 &

PADDLEX_PID=$!

# Wait for PaddleX to become ready
echo "Waiting for PaddleX to start on :8080 ..."
for i in $(seq 1 300); do
  if curl -sf http://127.0.0.1:8080/health > /dev/null 2>&1; then
    echo "PaddleX is ready."
    break
  fi
  sleep 1
done

# Start auth proxy in foreground
exec uvicorn auth_proxy:app --host 0.0.0.0 --port 8000 --workers 1
