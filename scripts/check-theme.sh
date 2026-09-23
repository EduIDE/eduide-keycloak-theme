#!/usr/bin/env bash
#
# Lint the theme structure, and guard the one bet this theme makes.
#
# Because theme.properties uses parent=base, and base ships no theme.properties
# at all, every ${properties.kcXxxClass!} in the ~45 templates we inherit
# resolves to whatever WE define. If a Keycloak upgrade starts using a class
# hook we have not named, the affected element silently loses its styling on a
# production login page, months later, with nobody looking.
#
# Check 5 below re-extracts the key list from upstream and fails on drift.
# That is the reason this script exists.
#
# Checks:
#   1. theme.properties parses, no duplicate keys
#   2. every file named in styles=/scripts=/stylesCommon= exists
#   3. every ${url.resourcesPath}/... our templates reference exists
#   4. keycloak-themes.json is valid, and matches the directories on disk
#   5. every properties.kc* upstream uses is defined by us

set -euo pipefail

cd "$(dirname "$0")/.."

KEYCLOAK_TAG="${KEYCLOAK_TAG:-26.4.0}"
CACHE_DIR="${TMPDIR:-/tmp}/eduide-base-login-${KEYCLOAK_TAG}"

fail=0
err() { echo "  FAIL: $*" >&2; fail=1; }

# Deliberately left empty. An empty value is a valid no-op: Keycloak emits
# class="" and our stylesheet does not need the hook.
INTENTIONALLY_EMPTY="kcButtonLargeClass"

for type in login email; do
    props="theme/eduide/${type}/theme.properties"
    [[ -f "$props" ]] || continue
    echo "==> ${type}"

    # 1. parses, no duplicates
    if grep -vE '^\s*(#|$)' "$props" | grep -qvE '^[A-Za-z0-9_.-]+='; then
        err "$props has a line that is neither a comment nor key=value"
    fi
    dups="$(grep -oE '^[A-Za-z0-9_.-]+=' "$props" | tr -d '=' | sort | uniq -d || true)"
    [[ -z "$dups" ]] || err "$props defines duplicate keys: $(echo "$dups" | tr '\n' ' ')"

    # 2. declared resources exist
    for key in styles scripts; do
        line="$(grep -E "^${key}=" "$props" || true)"
        [[ -n "$line" ]] || continue
        for ref in ${line#*=}; do
            [[ -f "theme/eduide/${type}/resources/${ref}" ]] \
                || err "${props}: ${key} names ${ref}, which does not exist under resources/"
        done
    done

    # 3. resource paths our own templates reference. Paths resolved through
    # theme inheritance (js/, and anything under resourcesCommonPath) are
    # skipped - those legitimately live in the parent theme.
    while IFS= read -r ref; do
        case "$ref" in
            js/*) continue ;;
        esac
        [[ -f "theme/eduide/${type}/resources/${ref}" ]] \
            || err "${type}: a template references resources/${ref}, which does not exist"
    done < <(grep -rhoE '\$\{url\.resourcesPath\}/[A-Za-z0-9_./-]+' "theme/eduide/${type}" --include='*.ftl' 2>/dev/null \
             | sed 's|${url.resourcesPath}/||' | sort -u || true)
done

# 4. keycloak-themes.json agrees with the tree
python3 - <<'PY' || fail=1
import json, pathlib, sys
data = json.load(open("META-INF/keycloak-themes.json"))
ok = True
for entry in data["themes"]:
    name, types = entry["name"], set(entry["types"])
    root = pathlib.Path("theme") / name
    if not root.is_dir():
        print(f"  FAIL: keycloak-themes.json declares theme '{name}', but theme/{name}/ does not exist", file=sys.stderr)
        ok = False
        continue
    on_disk = {p.name for p in root.iterdir() if p.is_dir()}
    for missing in types - on_disk:
        print(f"  FAIL: '{name}' declares type '{missing}' with no theme/{name}/{missing}/ directory", file=sys.stderr)
        ok = False
    for undeclared in on_disk - types:
        print(f"  FAIL: theme/{name}/{undeclared}/ exists but is not declared in keycloak-themes.json", file=sys.stderr)
        ok = False
sys.exit(0 if ok else 1)
PY

# 5. the drift check
echo "==> upstream kc* drift (keycloak ${KEYCLOAK_TAG})"
if ! command -v gh >/dev/null 2>&1; then
    echo "  note: gh not available; skipping drift check" >&2
else
    mkdir -p "$CACHE_DIR"
    if [[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
        files="$(gh api "repos/keycloak/keycloak/contents/themes/src/main/resources/theme/base/login?ref=${KEYCLOAK_TAG}" \
                  --jq '.[]|select(.type=="file")|.name' 2>/dev/null || true)"
        for f in $files; do
            case "$f" in
                *.ftl) gh api -H "Accept: application/vnd.github.raw" \
                        "repos/keycloak/keycloak/contents/themes/src/main/resources/theme/base/login/${f}?ref=${KEYCLOAK_TAG}" \
                        > "${CACHE_DIR}/${f}" 2>/dev/null || true ;;
            esac
        done
    fi
    if [[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
        echo "  note: could not fetch base templates (offline?); skipping drift check" >&2
    else
        used="$(cat "${CACHE_DIR}"/*.ftl | grep -oE 'properties\.kc[A-Za-z0-9_-]+' | sed 's/properties\.//' | sort -u)"
        defined="$(grep -oE '^kc[A-Za-z0-9_-]+' theme/eduide/login/theme.properties | sort -u)"
        for key in $used; do
            printf '%s\n' "$defined" | grep -qx "$key" \
                || err "upstream uses properties.${key}, which theme.properties does not define"
        done
        for key in $defined; do
            printf '%s\n' "$used" | grep -qx "$key" \
                || echo "  note: we define ${key}, which base ${KEYCLOAK_TAG} no longer uses" >&2
        done
        for key in $INTENTIONALLY_EMPTY; do
            grep -qE "^${key}=$" theme/eduide/login/theme.properties \
                || echo "  note: ${key} is documented as intentionally empty but now has a value" >&2
        done
    fi
fi

if (( fail )); then
    echo "theme check FAILED" >&2
    exit 1
fi
echo "theme check passed"
