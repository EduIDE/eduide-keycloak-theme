# EduIDE Keycloak theme

The login and email theme for EduIDE. It gives Keycloak the EduIDE look, and it
puts a data protection statement in front of users as something they read and
tick before they can continue.

**This repository is a theme, not a Keycloak deployment.** It builds one JAR
that you drop into a Keycloak you already run. It ships no server, no realm and
no institution's branding beyond EduIDE's own.

| | |
|---|---|
| Theme name | `eduide` |
| Types | `login`, `email` |
| Keycloak | 26.0 and newer (developed and verified against 26.4) |
| Artifact | `eduide-keycloak-theme-<version>.jar`, attached to each release |
| Licence | EPL-2.0 |

## What it looks like

A centred card on a soft teal-to-orange wash, with the EduIDE mark above it.
Brand teal `#249EA0` and orange `#F78104` come straight from the EduIDE logo.
Headings and buttons are set in Anonymous Pro, self-hosted rather than pulled
from Google Fonts; form fields and the statement body use a system sans,
because a multi-section legal text set in monospace is not readable.

Light and dark both ship, chosen from `prefers-color-scheme`. There is
deliberately no theme toggle - see "Dark mode" in `docs/customising.md`.

## Install

Three routes, compared properly in `docs/deployment.md`. **Check first whether
your Keycloak image is built with `--optimized`** - it rules one of them out.

```bash
# A. copy the directory - no JAR, no kc.sh build, no restart.
#    Does not survive a container restart; use it to try the theme out.
cp -r theme/eduide /opt/keycloak/themes/eduide

# B. the provider JAR - one versioned file, but kc.sh build is mandatory.
#    On an --optimized image a JAR without a rebuild makes Keycloak REFUSE
#    TO START, so bake both lines into the image.
./scripts/build-jar.sh 1.0.0
cp dist/eduide-keycloak-theme-1.0.0.jar /opt/keycloak/providers/
/opt/keycloak/bin/kc.sh build

# C. unpack the release JAR into the themes directory - the Kubernetes answer.
#    Versioned like B, installs like A: no rebuild, works on --optimized.
unzip -o eduide-keycloak-theme-1.0.0.jar "theme/*" -d /tmp/x
cp -r /tmp/x/theme/. /opt/keycloak/themes/
```

Then in the admin console set **Realm settings -> Themes -> Login theme:
`eduide`**, and Email theme `eduide`. `docs/deployment.md` has the init-container
manifest for route C, the realm checklist, the verification command and how to
roll back.

## Replacing the data protection statement

The text this theme ships is a **placeholder on purpose**. It names no data
controller, because a statement naming the wrong one is worse than an obvious
placeholder.

Your own text goes in as Keycloak realm localization overrides, which take
precedence over the theme bundle - so **no rebuild and no fork**:

```bash
./scripts/apply-localization.sh <realm> deploy/localization/eduide-tum.en.json \
                                        deploy/localization/eduide-tum.de.json
```

Those two files are EduIDE's real statement for the TUM deployment, and double
as a worked example of the format. Copy them, edit the text, apply.

**Override every locale your realm has enabled.** Keycloak resolves overrides
per locale as `realm-de > theme-de > realm-en > theme-en`, so an English-only
override still leaves German users reading this theme's German text.

## Develop

```bash
docker compose up                 # http://127.0.0.1:8080, admin / admin
```

Two realms are imported, theme caches are off so `.ftl` and `.css` edits show
on refresh, and Mailpit catches outgoing mail at http://127.0.0.1:8025.
`docs/development.md` lists the URL for every page worth looking at.

```bash
./scripts/check-messages.sh       # message bundles
./scripts/check-theme.sh          # theme structure + upstream drift
```

## Documentation

| | |
|---|---|
| `docs/deployment.md` | installing, realm settings, verifying, rolling back |
| `docs/customising.md` | changing the text, the colours and the logo |
| `docs/development.md` | the dev stack and every page to check |
| `AGENTS.md` | how the theme is built, and the traps |
