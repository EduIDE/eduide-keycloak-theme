# Deploying the EduIDE Keycloak theme

For whoever administers the Keycloak. Nothing here assumes EduIDE ran it, and
nothing here is specific to one institution.

## What you are installing

A login theme and an email theme, both named `eduide`, installed either as a
directory or as a provider JAR. Either way the install is **server-wide but
inert**: it adds an option to the Themes dropdown and changes nothing for any
realm until a realm selects it. If this Keycloak also serves other realms, they
are unaffected.

Requires Keycloak **26.0 or newer**.

## 1. Install the theme

Three routes. All verified against Keycloak 26.4 in **production** mode, and
one of them is ruled out entirely if your image is built with `--optimized`, so
read that part before choosing.

### The `--optimized` question decides this

If your Keycloak image was built with `kc.sh build` and is started with
`--optimized` - which is the recommended production setup and what most
container deployments do - then:

| Route | On an `--optimized` image |
|---|---|
| Provider JAR dropped into `providers/` | **Keycloak refuses to start.** Exit code 2, `A provider JAR was updated since the last build, please rebuild for this to be fully utilized.` |
| Theme directory under `themes/` | Works. No rebuild, no restart needed. |

That is not a silent degradation - the server goes down. A provider JAR on an
optimized image is only safe if you also rebuild the image. The themes
directory is read at runtime and is unaffected by augmentation.

### Option A - copy the directory

Keycloak reads themes straight out of `/opt/keycloak/themes/`. The contents of
`theme/` in this repo map one-to-one onto it, so installing is a copy of a
single directory:

```bash
cp -r theme/eduide /opt/keycloak/themes/eduide
```

That is the whole install. No JAR, no `META-INF/keycloak-themes.json`, **no
`kc.sh build`, and no restart** - the theme appears in the Themes dropdown
immediately, and later edits to `.ftl` and `.css` files are picked up on the
next request.

The catch is persistence. A copy into a running container lives in the
container filesystem and **is gone on the next restart**, so this is a way to
try the theme out, not a way to install it. For a real install the directory
has to come from somewhere that outlives the container - see Option C.

### Option B - the provider JAR

```bash
./scripts/build-jar.sh 1.0.0
cp dist/eduide-keycloak-theme-1.0.0.jar /opt/keycloak/providers/
/opt/keycloak/bin/kc.sh build
```

Then restart Keycloak.

The rebuild is mandatory, not advisory - see the table above. In exchange you
get one file with a version in its name, so what is deployed is identifiable
and a rollback is a file swap.

This is the right route when the Keycloak image is built in CI and you can add
a line to it:

```dockerfile
COPY eduide-keycloak-theme-1.0.0.jar /opt/keycloak/providers/
RUN /opt/keycloak/bin/kc.sh build
```

### Option C - unpack the release JAR into the themes directory

This is the one to use on Kubernetes, and the one to ask for if someone else
operates the Keycloak and does not want to rebuild their image. It takes the
versioned artifact from Option B and installs it the way Option A does, so it
needs no `kc.sh build`, works on an `--optimized` image, and still has a
version you can point at.

The release JAR is a plain zip, so unpacking `theme/` out of it is all that
happens:

```bash
unzip -o "eduide-keycloak-theme-1.0.0.jar" "theme/*" -d /tmp/x
cp -r /tmp/x/theme/. /opt/keycloak/themes/
```

As a Kubernetes init container writing into a volume that Keycloak mounts at
`/opt/keycloak/themes`:

```yaml
spec:
  volumes:
    - name: themes
      emptyDir: {}
  initContainers:
    - name: fetch-eduide-theme
      image: alpine:3
      command: ["/bin/sh", "-c"]
      args:
        - |
          set -eu
          apk add --no-cache unzip curl
          curl -fsSL -o /tmp/theme.jar \
            https://github.com/EduIDE/eduide-keycloak-theme/releases/download/v1.0.0/eduide-keycloak-theme-1.0.0.jar
          unzip -o -q /tmp/theme.jar "theme/*" -d /tmp/x
          cp -r /tmp/x/theme/. /themes/
      volumeMounts:
        - name: themes
          mountPath: /themes
  containers:
    - name: keycloak
      # unchanged, including --optimized
      volumeMounts:
        - name: themes
          mountPath: /opt/keycloak/themes
          readOnly: true
```

Pin the release tag, and the version that is live is whatever that URL says.
The init container re-runs on every pod start, so the theme survives restarts
and reschedules without any writable volume.

A ConfigMap works too, but is worse here: the theme is 18 files and five of
them are binary - four `.woff2` and `favicon.ico` - so they have to go in
`binaryData` as base64, and the result carries no version.

### Which to ask TUM for

Ask whether their Keycloak image is built with `--optimized`. If it is - and it
probably is - then **Option C**: it needs no change to their image, no
`kc.sh build`, and no restart beyond the normal rollout, while still pinning a
release tag. Option B is equally good if they are willing to add two lines to
their Dockerfile.

Option A is for trying it out on a staging instance, not for production.

### Browser caching applies to all three

Theme resources are served with `Cache-Control: max-age=2592000` - 30 days -
under a path like `/resources/<hash>/login/eduide/css/login.css`. That `<hash>`
is Keycloak's own resource version: **it does not change when the theme
changes.** So updating the stylesheet in place leaves returning visitors on the
old CSS until their cache expires.

This is a property of Keycloak themes, not of how you installed one. In
practice: change wording through realm localization overrides (step 4), which
are not cached this way, and expect a CSS or template change to reach returning
users gradually unless the Keycloak version also changed.

## 2. Select the theme

Admin console, on the realm that should use it:

- **Realm settings -> Themes -> Login theme** -> `eduide`
- **Realm settings -> Themes -> Email theme** -> `eduide`

If the dropdown does not list `eduide`, step 1 did not take effect - almost
always the missing `kc.sh build`.

## 3. Configure the realm

The theme renders what the realm asks for. These settings are what turn it into
a working login, registration and consent experience. All of it is done in the
admin console - nothing here needs the CLI. Menu labels below are Keycloak 26.4
verbatim.

| Where | Setting | Value |
|---|---|---|
| Realm settings -> Login | User registration | On, if users may self-register |
| Realm settings -> Login | Forgot password | On |
| Realm settings -> Login | Verify email | On, if registration is on |
| Realm settings -> Localization | Internationalization | On, with `en` and `de` |
| Realm settings -> Email | SMTP | Configured, or no mail is sent at all |
| Authentication -> Required actions | **Terms and Conditions** | Enabled, **Set as default action** on |
| Authentication -> Flows -> registration -> registration form | Terms and conditions | **Disabled** |

### Turning consent on, click by click

1. **Authentication** in the left nav, then the **Required actions** tab.
2. Find the row **Terms and Conditions**. Two toggles on it:
   - **Enabled** - on. This makes the action available at all.
   - **Set as default action** - on. This is the one that matters: it assigns
     the action to every **newly created** user, so they consent at first login.
3. Leave the registration form execution alone. To confirm it is off:
   **Authentication -> Flows -> registration**, expand **registration form**,
   and check the **Terms and conditions** row is set to **Disabled**.

**Enabled without Set as default action** is a valid state and a useful one: the
consent page then only appears for users you assign it to by hand. That is how
you re-consent a subset of people.

### Making existing users consent again

*Set as default action* only affects users created after you switch it on. It
does nothing for people who already have accounts. To put an existing user
through the consent page:

**Users -> pick the user -> Details -> Required user actions**, add
**Terms and Conditions**, Save. They get the page at their next login.

For everyone at once, script it over the Admin REST API - the console has no
bulk edit. The same applies after the statement changes and you want fresh
consent: clearing a user's `terms_and_conditions` attribute
(**Users -> user -> Attributes**) is what makes the page appear again.

### Why consent is configured this way

Keycloak offers two consent surfaces, and **you want exactly one of them**.

*Terms and Conditions* as a required action shows the consent page after login
and records the acceptance as the `terms_and_conditions` user attribute,
holding the epoch seconds of the moment Accept was submitted. That attribute is
the artifact to point at if anyone asks when a user consented.

The registration-form checkbox is the other surface. Upstream,
`RegistrationTermsAndConditions.success()` is an empty method: the checkbox is
validated and then **nothing is recorded** and the required action is not
marked satisfied. Enable both and a user who just ticked the box during
registration is shown the consent page again immediately.

So: required action on and set as a default action, registration execution
disabled. Consent then happens once, for new and existing users alike, and is
recorded.

If you prefer in-form consent instead, invert the two settings and accept that
nothing is recorded and existing users never consent. `dev/realm-eduide-registration-terms.json`
shows that configuration.

**One honest limitation.** `TermsAndConditions.processAction()` accepts any POST
that does not carry `cancel`, so the checkbox on the consent page is a usability
gate rather than a server-side control - a crafted request can skip it.
Enforcing it server-side would need a custom Java `RequiredActionProvider`,
which this repo deliberately does not ship. The registration-form checkbox, by
contrast, *is* server-enforced by its `validate()` method.

## 4. Install your data protection statement

**The text shipped in the theme is a placeholder.** It states that no statement
has been published, and names no data controller - a statement naming the wrong
controller would be worse. Replace it before real use.

Your text goes in as realm localization overrides, which take precedence over
the theme bundle, so this needs no rebuild and no fork. Either from the admin
console, or with the script.

**From the admin console**, one key at a time:

1. **Realm settings -> Localization**. Make sure **Internationalization** is on
   and your languages are in **Supported locales** first - the override tab is
   organised by language.
2. Open the **Realm overrides** tab.
3. **Add translation**. Pick the language, then enter the key and the value:

   | Key | Value |
   |---|---|
   | `termsText` | your statement, as HTML |
   | `termsTitle` | the page heading |
   | `acceptTerms` | the checkbox label |
   | `acceptTermsHelp` | the hint under the checkbox |
   | `termsAcceptanceRequired` | the error when the box is not ticked |
   | `footerPrivacyUrl`, `footerImprintUrl`, `footerHelpUrl` | footer links; each link is hidden while its URL is empty |

4. Save, and reload the consent page. **The change is live immediately** - no
   restart, no cache flush. Verified on 26.4.

Repeat for every language in Supported locales. The value box takes HTML
directly, so `termsText` is pasted in as one block of `<h2>`/`<p>`/`<ul>`.

**With the script**, for a whole file at once - better when the statement is
long or lives in git:

```bash
./scripts/apply-localization.sh <realm> \
    deploy/localization/eduide-tum.en.json \
    deploy/localization/eduide-tum.de.json
```

Those two files are EduIDE's statement for the TUM deployment; copy them, edit
the text, and apply your own. The same mechanism sets the footer links
(`footerImprintUrl`, `footerPrivacyUrl`, `footerHelpUrl`) - each link is hidden
while its URL is empty, so a realm that sets nothing gets a clean footer rather
than dead links.

**Override every locale the realm has enabled.** Keycloak resolves overrides per
locale, as `realm-de > theme-de > realm-en > theme-en`. Overriding only English
leaves German users reading the theme's German placeholder.

`docs/customising.md` covers the format, the HTML that survives sanitization,
and the escaping rules.

### Re-consent after the statement changes

Covered under "Making existing users consent again" above: clear the
`terms_and_conditions` attribute, or add the required action back to the users
concerned.

## 5. Verify

```bash
curl -s "https://<keycloak-host>/realms/<realm>/protocol/openid-connect/auth\
?client_id=<client>&response_type=code&scope=openid&redirect_uri=<redirect>" \
  | grep -o 'resources/[^/]*/login/[a-z]*'
```

Prints `resources/<hash>/login/eduide` when the theme is live.

Then look at the pages themselves: the login form, the consent page, and - if
registration is on - the registration form. `docs/development.md` lists how to
reach each one.

## Rolling back

Clear the Login theme and Email theme fields on the realm. It takes effect
immediately: no restart, no redeploy, and the theme can stay installed.

To roll back to an older *version* of the theme, replace the JAR and rebuild
(Option B), or re-copy the directory from the tag you want (Option A). Option B
is the one where "which version is live" has an answer without diffing files.

## Operational notes

- **Leave theme caching on in production.** The `--spi-theme-cache-themes`,
  `--spi-theme-cache-templates` and `--spi-theme-static-max-age` flags in
  `docker-compose.yml` exist so edits show up during development. In production
  they cost you page-render performance for nothing, and a JAR swap needs a
  restart regardless.
- **Content Security Policy.** The theme loads no third-party scripts, styles,
  fonts or images - fonts are self-hosted and icons are inline CSS - so it works
  under a strict CSP. It does rely on inline `<script type="module">` blocks
  that Keycloak itself emits for session checking; a CSP forbidding inline
  scripts would break those for every theme, not just this one.
- **German message fallback.** Keycloak's own German bundle ships in the
  community distribution. On a build that omits it, inherited strings fall back
  to English while the keys this theme defines still translate.
