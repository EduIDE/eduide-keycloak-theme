#!/usr/bin/env bash
#
# Install a realm's own texts as Keycloak realm localization overrides.
#
# This is the seam that makes the theme reusable without forking: realm
# overrides beat the theme's message bundle, so a deployment replaces the
# privacy statement, the footer links and any other string from outside the
# JAR. Verified upstream - FreeMarkerLoginFormsProvider calls
# theme.getEnhancedMessages(realm, locale), which merges realm texts over theme
# texts (LocaleUtil.mergeGroupedMessages, realm texts as firstMessages).
#
# IMPORTANT: precedence resolves per locale, as
#     realm-de > theme-de > realm-en > theme-en
# so overriding only English still leaves German users reading the theme's
# German text. Apply every locale the realm has enabled.
#
# Usage:
#   ./scripts/apply-localization.sh <realm> <file.<locale>.json>...
#
# Environment:
#   KC_URL        default http://127.0.0.1:8080
#   KC_USER       default admin          (ignored if KC_TOKEN is set)
#   KC_PASSWORD   default admin
#   KC_TOKEN      an existing admin access token, to skip password auth

set -euo pipefail

if [[ $# -lt 2 ]]; then
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi

REALM="$1"; shift
KC_URL="${KC_URL:-http://127.0.0.1:8080}"

if [[ -n "${KC_TOKEN:-}" ]]; then
    token="$KC_TOKEN"
else
    token="$(curl -fsS -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
        -d "username=${KC_USER:-admin}" \
        -d "password=${KC_PASSWORD:-admin}" \
        -d 'grant_type=password' \
        -d 'client_id=admin-cli' \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
fi

for file in "$@"; do
    [[ -f "$file" ]] || { echo "error: no such file: $file" >&2; exit 1; }

    # The locale is the second-to-last dot-separated component:
    # eduide-tum.de.json -> de
    base="$(basename "$file")"
    locale="${base%.json}"
    locale="${locale##*.}"
    if [[ ! "$locale" =~ ^[a-z]{2}(-[A-Za-z0-9]+)?$ ]]; then
        echo "error: cannot read a locale from '${base}'; name files like <name>.<locale>.json" >&2
        exit 1
    fi

    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d,dict) and all(isinstance(v,str) for v in d.values()), "must be a flat object of string values"' "$file"

    curl -fsS -X POST "${KC_URL}/admin/realms/${REALM}/localization/${locale}" \
        -H "Authorization: Bearer ${token}" \
        -H 'Content-Type: application/json' \
        --data-binary "@${file}"

    echo "applied $(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))))' "$file") keys to ${REALM} [${locale}]"
done
