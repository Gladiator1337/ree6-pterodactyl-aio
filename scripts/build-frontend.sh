#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/container"
FRONTEND="${ROOT}/runtime/frontend"
STATE="${ROOT}/.ree6-aio/frontend-build.sha256"

mkdir -p "$(dirname "${STATE}")"
desired="$(printf '%s\n%s\n%s\n' "${WEB_VERSION:-5.0.4}" "${BACKEND_URL}" "${INVITE_URL}" | sha256sum | awk '{print $1}')"
current="$(cat "${STATE}" 2>/dev/null || true)"

if [[ -f "${FRONTEND}/build/index.js" && "${desired}" == "${current}" ]]; then
    printf '[REE6-AIO] Frontend build is current.\n'
    exit 0
fi

printf '[REE6-AIO] Building frontend...\n'
cd "${FRONTEND}"
printf 'VITE_API_URL=%s\nVITE_INVITE_URL=%s\n' "${BACKEND_URL}" "${INVITE_URL}" > .env

if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
npm install --save-dev @sveltejs/adapter-node --force
sed -i 's|@sveltejs/adapter-auto|@sveltejs/adapter-node|g' svelte.config.js

npm run build
test -f build/index.js
printf '%s\n' "${desired}" > "${STATE}"
printf '[REE6-AIO] Frontend build completed.\n'
