# AGENTS.md - eduide-keycloak-theme

The Keycloak login and email theme for EduIDE. One JAR, dropped into a Keycloak
someone else runs. No server, no realm, no Java.

`CLAUDE.md` is a symlink to this file, so every agent reads the same thing.

## Layout

```
META-INF/keycloak-themes.json   declares the theme and its types to Keycloak
theme/eduide/login/             the login theme - 3 templates, 1 stylesheet
theme/eduide/email/             the email theme - 1 template, message-driven
deploy/localization/            EduIDE's real statement, as realm overrides
dev/                            two importable realms; see dev/README.md
scripts/                        build and lint; no toolchain required
docs/                           deployment, customising, development
```

**The repo root is the JAR's internal layout.** That is why `META-INF/` and
`theme/` sit at the top level: the build is one `zip` of those two directories,
with no staging step, and `docker-compose.yml` bind-mounts `theme/eduide`
straight into a container.

## Commands

```bash
docker compose up                       # dev stack, caches off, edits live
docker compose --profile jar up         # load the built JAR instead, as deployed
./scripts/build-jar.sh [version]        # -> dist/
./scripts/check-messages.sh             # message bundles
./scripts/check-theme.sh                # structure + upstream kc* drift
./scripts/check-agents-md.sh            # paths named in this file
./scripts/apply-localization.sh         # install a realm's own texts
```

CI runs the three `check-*` scripts and nothing else. **There is no smoke test**
- nothing in CI boots Keycloak, so a change that renders a broken page still
goes green. Run `docker compose up` and look at the pages.

## Only two templates are overridden, and that is the design

`theme.properties` sets `parent=base`. The base login theme ships **no
`theme.properties` at all**, so every `${properties.kcXxxClass!}` in the ~45
templates we inherit would be the empty string. Our `theme.properties` is not
overriding those keys - it is filling a vacuum. All 88 of them are defined, so
every page we never touch (`error.ftl`, `info.ftl`, `login-update-password.ftl`,
`register.ftl`, `select-authenticator.ftl`, ...) renders with our class names
against our one stylesheet.

That is what keeps the override list at `template.ftl` and `terms.ftl`.

**Before adding a third override, check whether a `kc*` property or a CSS hook
would do instead.** Most of the time it does. `register.ftl` is the case worth
remembering: the consent checkbox is styled entirely through
`kcCheckboxInputClass` and `#kc-registration-terms-text`, with no override.

`parent=keycloak` was rejected: it drags in PatternFly v3 and v4, ~400 KB of
CSS whose cascade you then fight forever.

## Traps

- **There is no favicon upstream.** `base/login/resources/img/` contains only
  `passkeys/`, yet base/login/template.ftl links img/favicon.ico. Under
  `parent=base` we must ship it, or every page 404s on it. The tidier
  `favicons=` property is 26.7+ only.
- **`kcFormPasswordVisibilityIconShow` / `...IconHide` must stay non-empty.**
  `passwordVisibility.js` assigns those strings onto the icon's `className`, so
  an empty value leaves an invisible dead control beside every password field.
- **Message values go through `MessageFormat`, always.** Write `''` for a
  literal apostrophe and quote braces. A lone `'` silently eats the next
  character.
- **`${...}` inside a message value** is substituted from system properties and
  environment variables before formatting. Never use it.
- **`msg("typo")` renders the literal key.** No warning, no log line, no error
  - just the string `acceptTermsHelp` sitting in the page. That is the entire
  reason `scripts/check-messages.sh` exists.
- **`kcSanitize` strips more than you expect**: `<details>`, `<section>`,
  `<button>`, `<form>` and `<script>` all vanish, and every `<a>` gains
  `rel="nofollow"`. The scrollable statement is CSS, not a disclosure widget.
- **Realm overrides resolve per locale**, as
  `realm-de > theme-de > realm-en > theme-en`. Overriding only English leaves
  German users on the theme's German text.
- **`RegistrationTermsAndConditions.success()` is an empty method.** The
  in-form consent checkbox validates and then records nothing - no
  `terms_and_conditions` attribute, no signal to the required action. Enable it
  *and* a default required action and the user consents twice. See
  `docs/deployment.md`.
- **Never override `user-profile-commons.ftl`.** Nine macros of declarative
  user-profile rendering that would need re-porting on every upgrade, and the
  `kc*` mapping already covers it.
- **Copy `template.ftl` from the pinned tag before editing it; never write one
  from scratch.** A `registrationLayout` macro that drops a `<#nested>` section
  blanks pages nobody tested. The theme this one replaces
  (`keycloak-tum-login-theme`, not in this repo) does exactly that: its macro
  omits `header`, `info`, `socialProviders` and `show-username`.
- **Never rename the theme directory.** Keycloak caches themes by name, and a
  realm pointing at a name that no longer exists falls back silently with no
  error.
- **Never hardcode an institution's name, URL or legal text in a template.**
  Titles come from `${realm.displayName}`; footer links come from message keys
  and hide themselves when empty.
- **JSON realm files take no comments.** `RealmRepresentation` is deserialised
  with unknown-field detection on, so a `_comment` key fails the whole import
  with `Unrecognized field`. Explanations go in `dev/README.md`.
- The vendored fonts under `theme/eduide/login/resources/fonts/` are not
  tracked by Renovate. Bump them by hand if ever needed.

## Upstream facts

This theme is a standing bet on templates we do not own, so every fact it
depends on is re-checkable. All were verified against **keycloak 26.4.0**.

Re-extract the class hooks base uses, which is what `check-theme.sh` compares
against `theme.properties`:

```bash
files=$(gh api "repos/keycloak/keycloak/contents/themes/src/main/resources/theme/base/login?ref=26.4.0" \
  --jq '.[]|select(.type=="file")|.name')
for f in $files; do
  gh api -H "Accept: application/vnd.github.raw" \
    "repos/keycloak/keycloak/contents/themes/src/main/resources/theme/base/login/$f?ref=26.4.0"
done | grep -oE 'properties\.kc[A-Za-z0-9_-]+' | sed 's/properties\.//' | sort -u
```

| Claim | Where it lives upstream |
|---|---|
| Realm overrides beat the theme bundle | `FreeMarkerLoginFormsProvider` -> `Theme.getEnhancedMessages` -> `LocaleUtil.mergeGroupedMessages`, realm texts passed as `firstMessages` |
| The in-form checkbox records nothing | `RegistrationTermsAndConditions.success()` and `setRequiredActions()` are empty |
| Consent is stored as epoch seconds | `TermsAndConditions.processAction()` writes the `terms_and_conditions` user attribute |
| Accept is not gated server-side | the same method accepts any POST that lacks `cancel` |
| base ships no `theme.properties` | the path 404s for both `base/login` and `base/email` |
| `msg("languages")` has no upstream definition | used in base/login/template.ftl, absent from every base bundle - we define it |

**A plain `zip` is a loadable theme provider.** Verified by running
`docker compose --profile jar up` against the built JAR and confirming
Keycloak served `resources/<hash>/login/eduide` with the stylesheet, fonts and
favicon all returning 200. CI does not re-check this; redo it by hand if the
build script changes.

## Conventions

- Git tags `vX.Y.Z`; the JAR filename carries the version without the `v`.
- 4-space indent in FTL, CSS and shell; 2 in JSON, YAML and Markdown.
- `--eduide-` prefix for CSS custom properties, `eduide-` for class names.
- Colours are defined **only** in section 2 of
  `theme/eduide/login/resources/css/login.css`. The email template is the one
  accepted duplication, because mail cannot load a stylesheet.
- Section order in that stylesheet is load-bearing and documented in its header.
