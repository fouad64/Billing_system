#!/bin/bash
(pkill -f "FINAL-SYNC-ENGINE.jar" || true)
nohup java -DDB_URL=jdbc:postgresql://localhost:5432/billing_db \
           -DDB_USER=zkhattab \
           -DDB_PASSWORD=kh007 \
           -jar FINAL-SYNC-ENGINE.jar > final_prod.log 2>&1 &
echo "Engine started in background with PID $!"
