#!/bin/bash
cd /var/www/finn/grok-repo
cp /var/www/finn/* .
git add .
git commit -m "Auto-sync grok files $(date)" || true
git push origin main
