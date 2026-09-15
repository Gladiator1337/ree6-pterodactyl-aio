#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="/home/container"
readonly DB_DIR="${ROOT}/database/mysql"
readonly DB_RUN="${ROOT}/database/run"
readonly DB_TMP="${ROOT}/database/tmp"
readonly DB_SOCKET="${DB_RUN}/mysqld.sock"
readonly DB_PID_FILE="${DB_RUN}/mysqld.pid"

MYSQL_PID=""
BACKEND_PID=""
BOT_PID=""
FRONTEND_PID=""
SHUTTING_DOWN=0

log() { printf '[REE6-AIO] %s\n' "$*"; }

stop_services() {
    if [[ "${SHUTTING_DOWN}" == "1" ]]; then return; fi
    SHUTTING_DOWN=1
    log "Stopping services..."

    for pid in "${FRONTEND_PID}" "${BOT_PID}" "${BACKEND_PID}"; do
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill -TERM "${pid}" 2>/dev/null || true
        fi
    done

    if [[ -S "${DB_SOCKET}" ]]; then
        mariadb-admin --protocol=socket --socket="${DB_SOCKET}" -uroot shutdown >/dev/null 2>&1 || true
    fi
    wait || true
}

trap stop_services SIGINT SIGTERM EXIT

mkdir -p "${DB_DIR}" "${DB_RUN}" "${DB_TMP}" "${ROOT}/logs"

if [[ ! -d "${DB_DIR}/mysql" ]]; then
    log "Initializing MariaDB data directory..."
    mariadb-install-db \
        --datadir="${DB_DIR}" \
        --auth-root-authentication-method=normal \
        --skip-test-db >/dev/null
fi

log "Starting MariaDB on 127.0.0.1:3306..."
mariadbd --no-defaults \
    --datadir="${DB_DIR}" \
    --socket="${DB_SOCKET}" \
    --pid-file="${DB_PID_FILE}" \
    --tmpdir="${DB_TMP}" \
    --bind-address=127.0.0.1 \
    --port=3306 \
    --skip-name-resolve \
    --max-connections=100 \
    --innodb-buffer-pool-size="${MARIADB_BUFFER_POOL_MB:-256}M" \
    --console &
MYSQL_PID=$!

for _ in {1..60}; do
    if mariadb-admin --protocol=socket --socket="${DB_SOCKET}" -uroot ping >/dev/null 2>&1; then break; fi
    if ! kill -0 "${MYSQL_PID}" 2>/dev/null; then log "MariaDB exited during startup."; exit 1; fi
    sleep 1
done
mariadb-admin --protocol=socket --socket="${DB_SOCKET}" -uroot ping >/dev/null 2>&1 || { log "MariaDB did not become ready."; exit 1; }

DB_NAME="${DATABASE_NAME:-ree6}"
DB_USER="${DATABASE_USER:-ree6}"
DB_PASS="${DATABASE_PASSWORD:?DATABASE_PASSWORD is required}"

[[ "${DB_NAME}" =~ ^[A-Za-z0-9_]+$ ]] || { log "Invalid DATABASE_NAME."; exit 1; }
[[ "${DB_USER}" =~ ^[A-Za-z0-9_]+$ ]] || { log "Invalid DATABASE_USER."; exit 1; }
[[ "${DB_PASS}" =~ ^[A-Za-z0-9_.@%+=:-]{12,64}$ ]] || { log "DATABASE_PASSWORD must be 12-64 safe characters."; exit 1; }

mariadb --protocol=socket --socket="${DB_SOCKET}" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
log "MariaDB is ready."

"${ROOT}/scripts/build-frontend.sh"

log "Starting backend on port ${BACKEND_PORT:-8888}..."
env config="${ROOT}/backend/config/config.yml" java -Xms128M -Xmx"${BACKEND_MEMORY_MB:-768}M" \
    -Dserver.port="${BACKEND_PORT:-8888}" \
    -jar "${ROOT}/runtime/backend/Webinterface.jar" &
BACKEND_PID=$!

log "Starting REE6 bot..."
env config="${ROOT}/bot/config/config.yml" java -Xms128M -Xmx"${BOT_MEMORY_MB:-1536}M" \
    -Dnogui=true \
    -jar "${ROOT}/runtime/bot/Ree6.jar" &
BOT_PID=$!

log "Starting frontend on port ${SERVER_PORT}..."
(
    cd "${ROOT}/runtime/frontend"
    exec env HOST=0.0.0.0 PORT="${SERVER_PORT}" NODE_ENV=production node build/index.js
) &
FRONTEND_PID=$!

log "All services started (frontend:${SERVER_PORT}, backend:${BACKEND_PORT:-8888}, MariaDB:localhost only)."

while true; do
    for pair in "MariaDB:${MYSQL_PID}" "Backend:${BACKEND_PID}" "Bot:${BOT_PID}" "Frontend:${FRONTEND_PID}"; do
        name="${pair%%:*}"; pid="${pair#*:}"
        if ! kill -0 "${pid}" 2>/dev/null; then
            wait "${pid}" || status=$?
            log "Critical service ${name} exited (status ${status:-0})."
            exit 1
        fi
    done
    sleep 2
done
