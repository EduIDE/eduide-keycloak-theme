# Ready-to-apply realm texts

Realm localization overrides for EduIDE's TUM deployment. Apply with:

```bash
../../scripts/apply-localization.sh <realm> eduide-tum-linked.en.json eduide-tum-linked.de.json
```

The locale comes from the filename, so `<name>.<locale>.json`. Apply **every**
locale the realm has enabled - Keycloak resolves overrides per locale as
`realm-de > theme-de > realm-en > theme-en`, so an English-only override leaves
German users on the theme's German placeholder.

## Two variants - pick one, do not apply both

| Files | `termsText` holds |
|---|---|
| `eduide-tum-linked.en.json`, `eduide-tum-linked.de.json` | a short summary plus a link to the statement on the landing page |
| `eduide-tum.en.json`, `eduide-tum.de.json` | the full statement, inline on the consent page |

**Linked** keeps the consent page short and leaves one copy of the policy to
maintain - the landing page is already the canonical source, and the two cannot
drift apart. The cost is a dependency: if the landing host is unreachable, the
consent page still renders and the checkbox still works, but the reader cannot
reach the detail. The summary paragraph is there so the essential facts are on
the page regardless.

**Inline** is self-contained and survives the landing page being down or moved,
but it is a second copy of a legal text that someone has to remember to update.

Both link the footer to `/imprint` and `/privacy` either way.

## The URL is environment-specific

Both variants point at `https://eduide.artemis.cit.tum.de` - the production
landing host. Every environment serves its own, so change the URL to match the
realm you are applying to. The landing hosts are listed in
EduIDE-deployment's `docs/environments.md`.

## Writing your own

Copy a file and edit. Three rules, because Keycloak reports none of them:

1. `MessageFormat` runs on every value - write `''` for a literal apostrophe and
   quote braces. These files avoid apostrophes entirely.
2. No `${...}` - it is substituted from system properties.
3. HTML is sanitized. `<p>`, `<a>`, `<ul>`, `<strong>` and friends survive;
   `<details>`, `<section>`, `<button>` and `<script>` are dropped silently.
   `target` may only be `_blank`, and Keycloak adds
   `rel="nofollow noopener noreferrer"` to every link itself.

Use `target="_blank"` on any link in `termsText`. The reader is mid-login, and a
same-tab navigation loses the authentication session.
