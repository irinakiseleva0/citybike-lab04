#!/usr/bin/env bash
# Runs ONE gate: start container -> wait for /health -> run test script -> clean up.
# Usage: bash scripts/run-gate.sh <image> <gate> <host_port> <container_name> [docker -e args...]
set -euo pipefail
IMAGE="$1"; GATE="$2"; PORT="$3"; NAME="$4"; shift 4

# 1. Remove any leftover container
docker rm -f "$NAME" >/dev/null 2>&1 || true

# 2. Start the image detached with the gate's config
docker run -d --name "$NAME" -p "${PORT}:4173" "$@" "$IMAGE" >/dev/null
export TARGET_URL="http://localhost:${PORT}"
export IMAGE_NAME="$IMAGE"

# 3. Poll /health with a real retry loop (timeout 30s)
echo "[$GATE] Waiting for ${TARGET_URL}/health ..."
ready=0
for i in $(seq 1 30); do
  if curl -sf "${TARGET_URL}/health" >/dev/null; then ready=1; break; fi
  if [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" != "true" ]; then
    echo "[$GATE] Container stopped before becoming healthy."; break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "[$GATE] FAIL: service not healthy. Container logs:"
  docker logs "$NAME" || true
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  exit 1
fi
echo "[$GATE] Healthy after ${i}s."

# 4. Run the gate's test script (unchanged, provided by the lab)
status=0
bash "./scripts/test-${GATE}.sh" || status=$?

# 5. Clean up (KEEP=1 keeps the container, used for prod on local runs)
if [ "${KEEP:-0}" != "1" ] || [ "$status" -ne 0 ]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
fi
exit "$status"
