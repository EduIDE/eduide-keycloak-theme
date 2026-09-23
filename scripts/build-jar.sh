#!/usr/bin/env bash
#
# Build the deployable theme JAR.
#
# There is no Java toolchain here and none is needed. A JAR is a ZIP, and
# Keycloak finds a theme provider by reading META-INF/keycloak-themes.json as a
# classloader resource - there are no classes to compile and no MANIFEST.MF to
# index. The repo root is laid out as the JAR's internal structure precisely so
# this is a single zip with no staging step.
#
# Usage: ./scripts/build-jar.sh [version]
#        version defaults to `git describe`, with any leading v stripped.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --always --dirty 2>/dev/null || echo 0.0.0-dev)}"
VERSION="${VERSION#v}"

OUT="dist/eduide-keycloak-theme-${VERSION}.jar"

mkdir -p dist
rm -f "$OUT"

# -X drops platform extra fields so the archive is reproducible for a given
# tree; -9 because this ships over the wire once and is read forever.
zip -r -X -9 "$OUT" META-INF theme \
    -x '*.DS_Store' -x '*/.git*' >/dev/null

# A JAR that is missing either of these loads without error and provides no
# theme, which is a miserable thing to debug on someone else's Keycloak.
# The listing is captured once rather than piped per check: `grep -q` closes
# the pipe on its first match, unzip takes SIGPIPE, and under `set -o pipefail`
# that reads as a failed check.
listing="$(unzip -l "$OUT")"
for required in META-INF/keycloak-themes.json theme/eduide/login/theme.properties; do
    if ! printf '%s\n' "$listing" | grep -q "$required"; then
        echo "error: $required missing from $OUT" >&2
        exit 1
    fi
done

echo "$OUT"
