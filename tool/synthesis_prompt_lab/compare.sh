#!/bin/bash
# Usage: compare.sh <name> <gguf path>  — restarts the local server on a model and runs the synthesis prompt checks.
S="$(cd "$(dirname "$0")" && pwd)"; cd "$S"
pkill -f "llama-server.*--port 8089"; sleep 1
(nohup llama-server -m "$2" -c 8192 --port 8089 -ngl 99 --reasoning-budget 0 > server.log 2>&1 &)
for i in $(seq 1 60); do curl -s localhost:8089/health | grep -q ok && break; sleep 1; done
{ echo "##### $1"; python3 syn.py thoughts.json eval; FOLDERSET=subject python3 syn.py thoughts.json eval
  for b in r08 r09 r02,r14,r11; do echo "=== write $b"; python3 syn.py thoughts.json write $b; done
  echo "=== update"; python3 syn.py thoughts.json update; } > "out_$1.txt" 2>&1
head -2 "out_$1.txt"
