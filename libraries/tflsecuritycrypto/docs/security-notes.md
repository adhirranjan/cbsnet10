# TflSecurityCrypto — Security Notes

What each primitive in this library is actually good for, why the weak ones are still here, and what to do when
you meet them in code. Companion to [../README.md](../README.md) and [api-reference.md](api-reference.md).

The short version:

> **`PasswordHash` is the only member of this library appropriate for new security work.** Everything else exists
> to read data the legacy VB.NET library wrote. Reaching for `Cryptography` or `RC4` in a new design is a defect,
> not a shortcut.

---

## 1. Decision table

| I need to… | Use | Do **not** use |
|---|---|---|
| Store a user password | `PasswordHash.Create` / `Verify` | `Cryptography.Encrypt` (either overload), `RC4` |
| Check a password at login | `PasswordHash.Verify` | anything that decrypts a stored password |
| Read a password stored by the legacy system | `Cryptography.Decrypt(…, true)` **once**, then immediately re-store via `PasswordHash.Create` | leaving it reversible |
| Encrypt data at rest (new) | ASP.NET Core Data Protection, or AES-GCM via `System.Security.Cryptography` | `Cryptography.Encrypt(…, true)` (3DES-ECB) |
| Protect a config secret | environment variables / secret store / `ProtectedData` | `AppConfigSectionProtector` (throws on .NET 10) |
| Random number for a security decision | `RandomNumberGenerator`, or `RNGCSP.RollDice` for a small die | `System.Random` |
| Obfuscate a value in transit to match the legacy web UI | `RC4` + `GetJsModuleScript()` | *(nothing new should need this)* |

---

## 2. Primitive-by-primitive

### PBKDF2 — `PasswordHash` ✅

**Sound.** PBKDF2-HMAC-SHA256, 600,000 iterations (OWASP guidance for this PRF), 128-bit per-password random salt,
256-bit derived key, constant-time comparison, self-describing versioned format so cost can rise without breaking
stored values.

Properties worth knowing:

- **Per-password salt** — identical passwords produce different hashes, so a stolen table shows no duplicates and
  rainbow tables are useless.
- **Adaptive cost** — raise `CurrentIterations`, deploy, and `NeedsRehash` upgrades each account silently at its
  next successful login. No mass reset, no downtime.
- **Fails closed, never throws** — malformed or tampered stored values verify as `false`. A corrupted column cannot
  turn into an exception path that a caller might mishandle into a successful login.
- **Not a KDF for encryption keys.** It is sized and formatted for password *verification*. If you need a key from
  a passphrase, derive it explicitly with your own parameters.

Residual considerations: PBKDF2 is memory-cheap, so it is weaker against GPU/ASIC attackers than Argon2id or
scrypt. That is a known, accepted trade-off — it ships in the BCL with no extra dependency. The `v1` version tag
is the migration path if that trade-off is ever revisited.

### MD5 — `Cryptography.Encrypt(string)` ⛔

Unsalted MD5. Collision-broken since 2004 and, being fast and unsalted, trivially reversible for passwords via
rainbow tables. Present only to reproduce legacy digests byte-for-byte. Never use it for passwords, integrity, or
signatures. (It is also used internally to *stretch the 3DES key*, below — that usage is not a security claim,
just key-length arithmetic.)

### Triple-DES ECB — `Cryptography.Encrypt/Decrypt(string, bool)` ⛔

Three compounding weaknesses:

1. **ECB mode** — identical plaintext blocks produce identical ciphertext blocks. Structure leaks; the classic
   "ECB penguin". There is no IV.
2. **Triple-DES** — 64-bit block cipher, deprecated by NIST (SP 800-131A) and vulnerable to Sweet32 birthday
   attacks on long-lived keys.
3. **The key is not secret.** It comes from the `SecurityKey` app setting *if one exists*; otherwise a hard-coded
   literal compiled into the assembly. On any ASP.NET Core host there is no `app.config`, so
   `ConfigurationManager.AppSettings["SecurityKey"]` returns `null` and the compiled-in default is always used.

Consequence: **treat every value protected this way as obfuscated, not encrypted.** Anyone with the DLL can
decrypt it. That is exactly why the CBS password migration to `PasswordHash` mattered — it moved credentials out of
a reversible scheme whose key ships with the application.

Keep using `Decrypt` to read existing data. Do not encrypt anything new with it.

### Salted SHA-256 — `Cryptography.Encrypt(string, string)` ⚠️

Better than MD5, still unsuitable for passwords: a **single** SHA-256 round is designed to be fast, so an attacker
tests billions of candidates per second. The salt defeats precomputation but not brute force. Also note the legacy
quirks documented in the API reference — the salt suffix is a fixed literal, and `VerifyHash` checks
self-consistency rather than comparing against a stored value.

Acceptable for non-secret checksums; not for credentials.

### RC4 — `RC4` ⛔

Prohibited for TLS since RFC 7465; biases in the keystream permit plaintext recovery. This implementation also
carries a shared, compiled-in key suffix (`mHexKey`) that is mirrored in the JavaScript twin returned by
`GetJsModuleScript()` — so the "key" is published to every browser that loads the login page.

Its only legitimate use is reproducing what the legacy WebForms screens did on the wire. It is **not** a substitute
for TLS: if the transport is HTTPS, RC4 adds nothing; if it is not, RC4 does not save you.

### Machine identity & licensing — `MachineIdentity`, `MachineIdentityValidator` ⚠️

A licensing/anti-copy mechanism, not a security boundary:

- The machine key is Triple-DES with the same non-secret key as everything else, so a licence file can be forged by
  anyone holding the DLL.
- `ValidateMachineIdentity` **returns `true` when it cannot read the hardware at all** (fail-open). On a locked-down
  service account or a non-Windows host, validation silently passes.
- WMI values (baseboard serial, volume serial) are frequently blank or duplicated on virtual machines and cloned
  images, so it is unreliable even as licensing.

Preserved for compatibility with existing deployments. Do not extend it, and do not treat a passing validation as
an authorisation decision.

### RNG — `RNGCSP.RollDice` ✅

Correct: seeded from the OS CSPRNG and rejection-sampled so the modulo does not bias the distribution. Fine for
what it does. For anything wider than a byte, call `RandomNumberGenerator.GetInt32` / `GetBytes` directly.

### Config protection — `AppConfigSectionProtector`, `ConfigFileProtection` ⛔ (inert)

Both throw `PlatformNotSupportedException` on .NET 10. This is honest behaviour — the alternative (silently doing
nothing) would leave a caller believing a section was encrypted when it was plaintext. If you hit one of these
exceptions, the fix is to move the secret out of the config file, not to reimplement the provider.

---

## 3. Key management, as it actually stands

| Key | Where it lives | Secret? |
|---|---|---|
| Triple-DES key | `SecurityKey` app setting if present, else a literal in `Cryptography.cs` | **No** — compiled into the assembly on .NET Core hosts |
| RC4 key suffix | `RC4.mHexKey`, also emitted into the browser by `GetJsModuleScript()` | **No** — published to every client |
| PBKDF2 salt | Generated per password, stored inside the hash string | N/A — salts are not secret by design |

There is no key rotation story for the legacy keys, because rotating them would make every existing ciphertext and
licence file unreadable. The migration path is not "rotate the key", it is **"stop using the primitive"** — which is
what `PasswordHash` is for.

---

## 4. Migrating a legacy value

The pattern used for the CBS user table, and the one to repeat:

```csharp
// At login, with the submitted plaintext in hand — the only moment you legitimately have it.
if (LooksLikeLegacyValue(stored))
{
    string legacyPlain = Cryptography.Decrypt(stored, useHashing: true);
    if (!FixedTimeEquals(legacyPlain, submitted)) return Unauthorized();

    stored = PasswordHash.Create(submitted);   // upgrade in place
    Save(stored);
}
else if (!PasswordHash.Verify(submitted, stored))
{
    return Unauthorized();
}
```

Points that matter:

- Upgrade **at login**, when the plaintext is legitimately present. A bulk migration cannot work — the whole point
  of a one-way hash is that you cannot derive it from a stored digest without the password.
- Once every row is migrated, delete the legacy branch. Leaving it in place keeps the weak path reachable, and an
  attacker who can influence the "looks like legacy" test gets to choose which one runs.
- Compare the legacy plaintext in constant time; a naive `==` on strings leaks length and prefix by timing.

CBS completed this for all 1,731 user records; the legacy branch there now exists only for data that predates the
migration.

---

## 5. Reviewing code that uses this library

Flag in review:

- `Cryptography.Encrypt` on **any new** write path — especially into a password, token, or key column.
- `RC4` anywhere outside the legacy login screen's compatibility shim.
- A `catch` around `PasswordHash.Verify` — it does not throw, so the catch is either dead code or hiding a
  different bug.
- A `ValidateMachineIdentity` result treated as an authorisation decision rather than a licensing hint.
- Any new call to the config-protection types — they throw, so the code path has never run.

Safe and expected:

- `PasswordHash.Create` / `Verify` / `NeedsRehash` anywhere credentials are handled.
- `Cryptography.Decrypt` on a **read** path for legacy data, ideally paired with an upgrade-on-read.
- `RNGCSP.RollDice`, `CharSetUtil.Chr`.

---

## 6. Assurance

| Property | Evidence |
|---|---|
| Port is byte-for-byte identical to the legacy VB library | `GoldenVectorTests.cs` — frozen vectors captured from the original `.vb` source, covering MD5, 3DES (both key modes), RC4, salted SHA-256, and all six `SimpleHash` algorithm branches |
| Legacy and new interoperate both directions | `Demo/Program.cs` — cross-decrypts ciphertext and cross-validates licences between the two assemblies, exit code non-zero on any mismatch |
| PBKDF2 invariants hold | `PasswordHashTests.cs` — verify/reject, per-call salt randomness, format shape (4 fields, 16-byte salt, 32-byte key), tampered-key rejection, malformed input returns false without throwing, `NeedsRehash` on missing/malformed/low-iteration values |
| Failure modes match legacy | Tests assert 3DES-with-unhashed-key throws and RC4-with-empty-key throws `DivideByZeroException`, exactly as the original did |

What is **not** covered: there has been no external cryptographic review, no side-channel analysis beyond using
`FixedTimeEquals`, and no fuzzing of the licence-file parser (which does index arithmetic on attacker-supplied
content — a hardening candidate if licence files ever arrive from an untrusted source).
