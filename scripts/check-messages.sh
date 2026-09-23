#!/usr/bin/env bash
#
# Lint the theme message bundles.
#
# This exists because Keycloak's msg() resolves a missing key to the key
# itself: a typo does not warn, does not log, and does not fail - it renders
# the literal string "acceptTermsHelp" as body text on a page real users see.
# Nothing else in the toolchain catches that.
#
# Checks, per theme type:
#   1. every literal key used in our .ftl exists in our bundle or in base's
#   2. our en and de bundles define the same keys
#   3. no duplicate keys within a file (.properties silently keeps the last)
#   4. both files are valid UTF-8
#   5. no value has an odd number of apostrophes (the MessageFormat trap)
#   6. no value contains ${...} (substituted from system properties)

set -euo pipefail

cd "$(dirname "$0")/.."

KEYCLOAK_TAG="${KEYCLOAK_TAG:-26.4.0}"
CACHE="${TMPDIR:-/tmp}/eduide-base-messages-${KEYCLOAK_TAG}.properties"

fail=0
err() { echo "  FAIL: $*" >&2; fail=1; }

# Base bundle, cached. Our templates legitimately use inherited keys such as
# doAccept and requiredFields, so "exists upstream" is a valid answer.
if [[ ! -s "$CACHE" ]]; then
    if command -v gh >/dev/null 2>&1; then
        gh api -H "Accept: application/vnd.github.raw" \
          "repos/keycloak/keycloak/contents/themes/src/main/resources/theme/base/login/messages/messages_en.properties?ref=${KEYCLOAK_TAG}" \
          > "$CACHE" 2>/dev/null || true
    fi
fi
if [[ -s "$CACHE" ]]; then
    base_keys="$(grep -oE '^[A-Za-z0-9_.-]+=' "$CACHE" | tr -d '=' | sort -u)"
else
    echo "  note: base bundle unavailable (no gh, or offline); skipping check 1" >&2
    base_keys=""
fi

for type in login email; do
    dir="theme/eduide/${type}"
    [[ -d "$dir" ]] || continue
    echo "==> ${type}"

    en="${dir}/messages/messages_en.properties"
    de="${dir}/messages/messages_de.properties"

    for f in "$en" "$de"; do
        [[ -f "$f" ]] || { err "$f missing"; continue; }

        # 4. encoding. A half-corrupt file mojibakes rather than failing, since
        # Keycloak falls back to ISO-8859-1 without saying so.
        iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1 || err "$f is not valid UTF-8"

        # 3. duplicates
        dups="$(grep -oE '^[A-Za-z0-9_.-]+=' "$f" | tr -d '=' | sort | uniq -d || true)"
        [[ -z "$dups" ]] || err "$f defines duplicate keys: $(echo "$dups" | tr '\n' ' ')"

        # 5 and 6. value-level traps
        while IFS= read -r line; do
            key="${line%%=*}"
            value="${line#*=}"
            quotes="$(printf '%s' "$value" | tr -cd "'" | wc -c | tr -d ' ')"
            (( quotes % 2 == 0 )) || err "$f: '$key' has an odd number of apostrophes; MessageFormat needs '' for a literal one"
            case "$value" in
                *'${'*) err "$f: '$key' contains \${...}, which Keycloak substitutes from system properties" ;;
            esac
        done < <(grep -E '^[A-Za-z0-9_.-]+=' "$f" || true)
    done

    # 2. en and de agree
    if [[ -f "$en" && -f "$de" ]]; then
        only_en="$(comm -23 <(grep -oE '^[A-Za-z0-9_.-]+=' "$en" | tr -d '=' | sort -u) \
                            <(grep -oE '^[A-Za-z0-9_.-]+=' "$de" | tr -d '=' | sort -u))"
        only_de="$(comm -13 <(grep -oE '^[A-Za-z0-9_.-]+=' "$en" | tr -d '=' | sort -u) \
                            <(grep -oE '^[A-Za-z0-9_.-]+=' "$de" | tr -d '=' | sort -u))"
        [[ -z "$only_en" ]] || err "keys only in en: $(echo "$only_en" | tr '\n' ' ')"
        [[ -z "$only_de" ]] || err "keys only in de: $(echo "$only_de" | tr '\n' ' ')"
    fi

    # 1. every key our templates ask for resolves somewhere
    if [[ -n "$base_keys" ]]; then
        ours="$(grep -hoE '^[A-Za-z0-9_.-]+=' "$en" 2>/dev/null | tr -d '=' | sort -u || true)"
        known="$(printf '%s\n%s\n' "$base_keys" "$ours" | sort -u)"
        used="$(grep -rhoE '(msg|advancedMsg)\((\"|'"'"')[A-Za-z0-9_.-]+' "$dir" --include='*.ftl' 2>/dev/null \
                | sed -E 's/.*[("'"'"']//' | sort -u || true)"
        for k in $used; do
            printf '%s\n' "$known" | grep -qx "$k" || err "${type}: msg(\"$k\") has no definition here or upstream"
        done
    fi
done

if (( fail )); then
    echo "message check FAILED" >&2
    exit 1
fi
echo "message check passed"
