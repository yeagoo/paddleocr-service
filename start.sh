#!/bin/bash
set -e

cleanup() {
  echo "Shutting down..."
  kill "$PADDLEX_PID" 2>/dev/null || true
  wait "$PADDLEX_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Start PaddleX on internal-only port in background
paddlex --serve \
  --pipeline /app/pipeline_config.yaml \
  --device cpu \
  --host 127.0.0.1 \
  --port 8080 &

PADDLEX_PID=$!

# Wait for PaddleX to become ready
echo "Waiting for PaddleX to start on :8080 ..."
READY=0
for i in $(seq 1 300); do
  if ! kill -0 "$PADDLEX_PID" 2>/dev/null; then
    echo "PaddleX process exited unexpectedly."
    exit 1
  fi
  if curl -sf http://127.0.0.1:8080/health > /dev/null 2>&1; then
    echo "PaddleX is ready."
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" -ne 1 ]; then
  echo "PaddleX failed to start within 300 seconds."
  exit 1
fi

# Start auth proxy in foreground
exec uvicorn auth_proxy:app --host 0.0.0.0 --port 8000 --workers 1
