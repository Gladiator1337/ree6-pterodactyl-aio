#!/usr/bin/env bash
set -Eeuo pipefail

export HOME=/mnt/server
ROOT=/mnt/server

log() { printf '[REE6-AIO installer] %s\n' "$*"; }

release_json() {
    local repo="$1" version="$2"
    if [[ -z "${version}" || "${version}" == "latest" ]]; then
        curl -fsSL "https://api.github.com/repos/${repo}/releases/latest"
    else
        curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/${version}"
    fi
}

mkdir -p \
    "${ROOT}/runtime/bot" "${ROOT}/runtime/backend" \
    "${ROOT}/bot/config" "${ROOT}/bot/storage" "${ROOT}/bot/languages" \
    "${ROOT}/backend/config" "${ROOT}/backend/storage" \
    "${ROOT}/database/mysql" "${ROOT}/database/run" "${ROOT}/database/tmp" \
    "${ROOT}/scripts" "${ROOT}/logs" "${ROOT}/.ree6-aio"

BUNDLED_BOT="/opt/ree6-aio/Ree6.jar"
BUNDLED_BOT_VERSION="$(cat /opt/ree6-aio/bot-version 2>/dev/null || true)"
REQUESTED_BOT_VERSION="${BOT_VERSION:-4.0.12}"
[[ -s "${BUNDLED_BOT}" ]] || { log "The runtime image does not contain the patched REE6 bot."; exit 1; }
[[ "${REQUESTED_BOT_VERSION}" == "${BUNDLED_BOT_VERSION}" ]] || {
    log "BOT_VERSION ${REQUESTED_BOT_VERSION} is not bundled in this runtime (expected ${BUNDLED_BOT_VERSION})."
    exit 1
}

WEB_JSON="$(release_json Ree6-Applications/Webinterface "${WEB_VERSION:-5.0.4}")"
BACKEND_URL_ASSET="$(jq -r '.assets[] | select(.name | test("Webinterface-Backend-.*\\.jar$")) | .browser_download_url' <<<"${WEB_JSON}" | head -n1)"
FRONTEND_TARBALL="$(jq -r '.tarball_url' <<<"${WEB_JSON}")"
[[ -n "${BACKEND_URL_ASSET}" && "${BACKEND_URL_ASSET}" != "null" ]] || { log "Unable to find the backend JAR."; exit 1; }

if [[ -f "${ROOT}/runtime/bot/Ree6.jar" ]]; then cp -f "${ROOT}/runtime/bot/Ree6.jar" "${ROOT}/runtime/bot/Ree6.jar.previous"; fi
if [[ -f "${ROOT}/runtime/backend/Webinterface.jar" ]]; then cp -f "${ROOT}/runtime/backend/Webinterface.jar" "${ROOT}/runtime/backend/Webinterface.jar.previous"; fi

log "Installing patched REE6 bot ${BUNDLED_BOT_VERSION}..."
cp "${BUNDLED_BOT}" "${ROOT}/runtime/bot/Ree6.jar.new"
mv -f "${ROOT}/runtime/bot/Ree6.jar.new" "${ROOT}/runtime/bot/Ree6.jar"

log "Downloading webinterface backend..."
curl -fL --retry 3 -o "${ROOT}/runtime/backend/Webinterface.jar.new" "${BACKEND_URL_ASSET}"
mv -f "${ROOT}/runtime/backend/Webinterface.jar.new" "${ROOT}/runtime/backend/Webinterface.jar"

log "Downloading webinterface frontend source..."
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
curl -fL --retry 3 -o "${tmp_dir}/webinterface.tar.gz" "${FRONTEND_TARBALL}"
mkdir -p "${tmp_dir}/source"
tar -xzf "${tmp_dir}/webinterface.tar.gz" -C "${tmp_dir}/source" --strip-components=1
[[ -f "${tmp_dir}/source/Frontend/package.json" ]] || { log "Frontend source is missing."; exit 1; }
if [[ -d "${ROOT}/runtime/frontend" ]]; then
    rm -rf "${ROOT}/runtime/frontend.previous"
    mv "${ROOT}/runtime/frontend" "${ROOT}/runtime/frontend.previous"
fi
mv "${tmp_dir}/source/Frontend" "${ROOT}/runtime/frontend"

cd "${ROOT}/runtime/frontend"
printf 'VITE_API_URL=%s\nVITE_INVITE_URL=%s\n' "${BACKEND_URL}" "${INVITE_URL}" > .env
if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
npm install --save-dev @sveltejs/adapter-node --force
sed -i 's|@sveltejs/adapter-auto|@sveltejs/adapter-node|g' svelte.config.js
npm run build
test -f build/index.js
printf '%s\n' "$(printf '%s\n%s\n%s\n' "${WEB_VERSION:-5.0.4}" "${BACKEND_URL}" "${INVITE_URL}" | sha256sum | awk '{print $1}')" > "${ROOT}/.ree6-aio/frontend-build.sha256"

if [[ ! -f "${ROOT}/bot/config/config.yml" ]]; then
    log "Generating bot configuration..."
    cd "${ROOT}/runtime/bot"
    timeout 15s env config="${ROOT}/bot/config/config.yml" java -jar Ree6.jar >/dev/null 2>&1 || true
fi

if [[ ! -f "${ROOT}/backend/config/config.yml" ]]; then
    log "Generating backend configuration..."
    cd "${ROOT}/runtime/backend"
    timeout 15s env config="${ROOT}/backend/config/config.yml" java -Dserver.port=0 -jar Webinterface.jar >/dev/null 2>&1 || true
fi

[[ -s "${ROOT}/bot/config/config.yml" ]] || { log "Bot config generation failed."; exit 1; }
[[ -s "${ROOT}/backend/config/config.yml" ]] || { log "Backend config generation failed."; exit 1; }

# SCRIPT_PAYLOADS

chmod +x "${ROOT}/scripts/start-all.sh" "${ROOT}/scripts/build-frontend.sh"
printf '%s\n' "bot=${BOT_VERSION:-4.0.12}" "web=${WEB_VERSION:-5.0.4}" > "${ROOT}/.ree6-aio/versions"
log "Installation completed."
