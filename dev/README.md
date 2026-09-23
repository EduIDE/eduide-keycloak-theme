# Development realms

Two importable realms. Neither is a production artifact - `docs/deployment.md`
carries the settings checklist for a real deployment. They exist so
`docker compose up` lands on a working login, registration and consent flow
with no admin-console clicking.

**These files carry no comments because Keycloak rejects them.**
`RealmRepresentation` is deserialised with unknown-field detection on, so a
`_comment` key does not import as an ignorable extra - it fails the whole
realm import with `Unrecognized field "_comment"`. Hence this file.

| File | Realm | Consent mechanism |
|---|---|---|
| `realm-eduide.json` | `eduide-dev` | `TERMS_AND_CONDITIONS` required action, set as a default action |
| `realm-eduide-registration-terms.json` | `eduide-dev-regterms` | `registration-terms-and-conditions` checkbox inside the registration form |

## Why two

The two consent mechanisms cannot both be enabled without asking the user
twice. `RegistrationTermsAndConditions.success()` and `setRequiredActions()`
are both empty methods upstream, so ticking the box during registration writes
no `terms_and_conditions` attribute and tells the required action nothing - a
user who just consented is immediately shown the consent page again.

`realm-eduide.json` is the configuration this theme recommends and the one
`docs/deployment.md` describes: consent happens once, on the styled terms page,
for new and existing users alike, and is recorded as an attribute.

`realm-eduide-registration-terms.json` exists so the styling of the stock
`register-commons.ftl` macro (`#kc-registration-terms-text`, `#termsAccepted`)
can be checked by hand. It spells out the whole registration flow because
supplying `authenticationFlows` replaces Keycloak's built-in flow generation,
and each execution carries both `authenticatorFlow` and the deprecated
misspelled `autheticatorFlow` that real Keycloak exports contain.

## Accounts

| User | Password | Purpose |
|---|---|---|
| `terms@example.com` | `password` | Has `TERMS_AND_CONDITIONS` pending, so logging in goes straight to the consent page |
| `plain@example.com` | `password` | Ordinary user, for the plain login path |
| `admin` | `admin` | Admin console at http://127.0.0.1:8080/admin |
