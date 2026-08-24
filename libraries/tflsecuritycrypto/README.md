# TflSecurityCrypto

**Product:** `Tssipl.Security.Cryptography` · **Assembly / namespace:** `TflSecurityCrypto` · **TFM:** `net10.0` · **Version:** 1.0.0.13

The in-house security library: **password hashing for storage**, plus a **byte-for-byte compatible port** of the
legacy VB.NET cryptography helpers so existing ciphertext, licence files and stored hashes remain readable
on .NET 10.

Two distinct jobs live in this one assembly, and keeping them apart is the whole point:

| | Use for | Types |
|---|---|---|
| **Forward-looking** | Anything new. Modern, salted, adaptive password storage. | `PasswordHash` |
| **Legacy-compatibility** | Reading data the old VB.NET library wrote. **Not** for new designs. | `Cryptography`, `RC4`, `MachineIdentity`, `MachineIdentityValidator` |

> **If you are storing a password, use [`PasswordHash`](#passwordhash---modern-password-storage) and nothing else.**
> `Cryptography.Encrypt` is unsalted MD5 or reversible Triple-DES-ECB; `RC4` is a broken stream cipher. They exist
> so that twenty years of stored values keep working — see [docs/security-notes.md](docs/security-notes.md).

---

## Contents

- [Quick start](#quick-start)
- [Referencing the library](#referencing-the-library)
- [Feature map](#feature-map)
- [`PasswordHash` — modern password storage](#passwordhash---modern-password-storage)
- [Legacy-compatibility surface](#legacy-compatibility-surface)
- [Platform notes](#platform-notes)
- [Components & repository layout](#components--repository-layout)
- [Compatibility guarantee & how it is proven](#compatibility-guarantee--how-it-is-proven)
- [Build, test, demo](#build-test-demo)
- [How TrustBank CBS uses this library](#how-trustbank-cbs-uses-this-library)
- [Further reading](#further-reading)

---

## Quick start

```csharp
using TflSecurityCrypto;

// ---- storing a password -------------------------------------------------
string stored = PasswordHash.Create(plainPassword);   // "v1$600000$<b64 salt>$<b64 key>"
// persist `stored` (a single string column, ~90 chars) — there is no separate salt column

// ---- verifying a login --------------------------------------------------
if (!PasswordHash.Verify(submittedPassword, stored))
    return Unauthorized();

// ---- transparent cost upgrade (optional, after a successful verify) -----
if (PasswordHash.NeedsRehash(stored))
    stored = PasswordHash.Create(submittedPassword);  // re-save at current parameters
```

That is the entire API for new work. Everything below is either detail or legacy interop.

---

## Referencing the library

It ships as a plain assembly reference (no NuGet feed). TrustBank CBS references the built DLL directly:

```xml
<Reference Include="TflSecurityCrypto">
  <HintPath>..\..\..\_Archive\Ad.ProjectLibrary\Tssipl.Security.Cryptography\TflSecurityCrypto\TflSecurityCrypto\bin\Debug\net10.0\TflSecurityCrypto.dll</HintPath>
</Reference>
```

Because it is a bare-DLL reference there is **no build-order edge** — build `TflSecurityCrypto` *first* whenever
you change it, then rebuild the consumer.

**Transitive package dependencies** (both required at runtime):

| Package | Version | Needed by |
|---|---|---|
| `System.Configuration.ConfigurationManager` | 9.0.0 | `Cryptography` (reads the `SecurityKey` app setting) |
| `System.Management` | 9.0.0 | `MachineIdentity` (WMI queries, Windows only) |

XML documentation is generated (`GenerateDocumentationFile=true`), so IntelliSense carries the per-member notes.

---

## Feature map

| Feature | Type | Status | Notes |
|---|---|---|---|
| PBKDF2 password hash / verify / rehash-check | `PasswordHash` | **Current** | PBKDF2-HMAC-SHA256, 600,000 iterations, 128-bit salt, 256-bit key |
| MD5 digest | `Cryptography.Encrypt(string)` | Legacy | Unsalted. Compatibility only |
| Triple-DES encrypt / decrypt (reversible) | `Cryptography.Encrypt/Decrypt(string, bool)` | Legacy | ECB + PKCS7, key from config or built-in default |
| Salted SHA-256 hash / verify | `Cryptography.Encrypt(string, string)` / `VerifyHash` | Legacy | Salt handling is the legacy Obviex scheme |
| RC4 stream cipher (string & byte[]) | `RC4` | Legacy | Plus `GetJsModuleScript()` for the browser-side twin |
| Cryptographic RNG | `RNGCSP.RollDice` | Current | Uniform 1..n via rejection sampling |
| CP1252 byte→char | `CharSetUtil.Chr` | Utility | VB `Chr()` equivalent |
| Windows hardware fingerprint | `MachineIdentity` | Legacy | WMI: baseboard, CPU, volume serial, MAC |
| Licence-file validation | `MachineIdentityValidator` | Legacy | Expiry prefix + trial window + machine binding |
| app.config / web.config section protection | `AppConfigSectionProtector`, `ConfigFileProtection` | **Not supported** | Throw `PlatformNotSupportedException` on .NET 10 — surface kept so callers still compile |

---

## `PasswordHash` — modern password storage

Static class. One-way: there is no "decrypt".

| Member | Signature | Behaviour |
|---|---|---|
| `Create` | `static string Create(string password)` | Fresh 128-bit random salt, derives a 256-bit key, returns the versioned string. Throws `ArgumentNullException` on a null password. **Two calls on the same password return different strings** — that is correct. |
| `Verify` | `static bool Verify(string password, string storedHash)` | Re-derives using the salt *and* iteration count embedded in `storedHash`, compares with `CryptographicOperations.FixedTimeEquals`. Returns `false` — **never throws** — for null / empty / malformed / tampered input. |
| `NeedsRehash` | `static bool NeedsRehash(string storedHash)` | `true` if the value is missing, unreadable, a non-current version, or uses fewer than `CurrentIterations`. Call it after a successful `Verify` to upgrade cost silently on next login. |
| `CurrentVersion` | `const string` = `"v1"` | Format tag. A future scheme (Argon2, say) becomes `v2`. |
| `CurrentIterations` | `const int` = `600_000` | OWASP guidance for PBKDF2-HMAC-SHA256. Tunable upward; raising it does not invalidate existing hashes. |

**Stored format** — one string, self-describing, `$`-delimited (`$` never occurs in Base64):

```
v1$600000$3Q2Ld9Xk1r7YbAcE8fGhIw==$K7pR2sT4uV6wX8yZ0aB2cD4eF6gH8iJ0kL2mN4oP6qQ=
│  │      │                        └── Base64 derived key   (32 bytes)
│  │      └── Base64 salt                                   (16 bytes)
│  └── iteration count actually used for THIS hash
└── format version
```

Because the iteration count travels with each hash, old and new hashes coexist and verify correctly. Parsing is
strict: wrong field count, unknown version, non-numeric or non-positive iterations, or invalid Base64 all parse
as failure (→ `Verify` false, `NeedsRehash` true).

**Sizing the column:** `v1` at 600,000 iterations is 4 + 7 + 25 + 45 ≈ **83 characters**. A `varchar(255)` column
leaves comfortable room for a future scheme.

---

## Legacy-compatibility surface

Full signature-level detail is in [docs/api-reference.md](docs/api-reference.md); the security posture of each
primitive is in [docs/security-notes.md](docs/security-notes.md). Summary:

### `Cryptography`

```csharp
byte[] Encrypt(string text)                            // raw MD5 of UTF-8 bytes
string Encrypt(string toEncrypt, bool useHashing)      // Triple-DES ECB/PKCS7 → Base64
string Decrypt(string cipherString, bool useHashing)   // inverse
byte[] Encrypt(string text, string salt)               // salted SHA-256, returns UTF-8 bytes of the Base64 hash string
bool   VerifyHash(string text, string salt)            // recompute-and-compare
```

- The Triple-DES key comes from the **`SecurityKey` app setting**, falling back to a hard-coded default literal
  (see `Cryptography.cs`). `useHashing: true` MD5-hashes the key first, producing the 16-byte two-key 3DES key —
  **this is the only working path**. `useHashing: false` passes the raw 14-byte default key to Triple-DES, which
  **throws** (invalid key size); the legacy library behaved identically, and a test pins that.
- On a .NET (Core) host with no `app.config`/`.exe.config`, `ConfigurationManager.AppSettings["SecurityKey"]` is
  `null`, so the built-in default key is used. That is precisely what lets ASP.NET Core hosts decrypt legacy
  ciphertext — but it also means the key is **not a secret**. Treat these values as obfuscated, not encrypted.

### `RC4`

```csharp
static string mHexKey                          // public field: the shared hex key suffix
static string GetRandomKey()                   // Guid-based
static string Encrypt(string key, string data) // UTF-16LE + Base64
static string Decrypt(string key, string data)
static byte[] Encrypt(byte[] key, byte[] data) // symmetric — Decrypt is the same transform
static byte[] Decrypt(byte[] key, byte[] data)
static string GetJsModuleScript()              // the minified browser-side RC4 + Base64 twin
```

An empty key throws `DivideByZeroException` in the key-scheduling loop — again matching the legacy behaviour, and
again pinned by a test. `GetJsModuleScript()` exists so a login page can RC4 the password client-side exactly the
way the legacy WebForms screens did.

### `MachineIdentity` / `MachineIdentityValidator`

Windows-only (`[SupportedOSPlatform("windows")]`, WMI via `System.Management`). `MachineIdentity.GenerateKey()`
builds a `key=value` block from baseboard serial + C: volume serial + processor id and Triple-DES-encrypts it.
`MachineIdentityValidator.ValidateMachineIdentity(licenseFile)` reads a licence file and:

1. if it starts with the date-time marker, decrypts the 24-char expiry prefix (`yyyyMMdd`) and throws
   `ApplicationException("License expired")` when past;
2. if the payload contains `TRIAL`, parses the start date and day count and throws
   `ApplicationException("License file expired.")` outside the window;
3. decrypts twice more and compares against this machine's key — returns `false` on mismatch.

Note the deliberate legacy quirk: **if the machine key cannot be generated at all, it returns `true`** (fail-open).
Preserved for compatibility; do not build new licensing on it.

### `RNGCSP`, `CharSetUtil`

`RNGCSP.RollDice(byte numberSides)` returns a uniform value in `1..numberSides` using rejection sampling over
`RandomNumberGenerator` (the incomplete final byte-set is discarded, so the distribution stays fair).
`CharSetUtil.Chr(int 0..255)` is the VB `Chr()` equivalent via code page 1252; out-of-range throws
`ArgumentOutOfRangeException`.

### Not supported on .NET 10

`AppConfigSectionProtector.ProtectConnectionString` / `UnprotectConnectionString` and
`ConfigFileProtection.ProtectSection` / `UnProtectSection` throw `PlatformNotSupportedException`. Protected-
configuration providers (`DataProtectionConfigurationProvider`) and `System.Web.Configuration` do not exist on
.NET (Core). The methods remain so dependent code compiles; if you need config encryption, use
`System.Security.Cryptography.ProtectedData` or ASP.NET Core Data Protection instead.

### Internal

`SimpleHash` (salted MD5/SHA-1/SHA-256/SHA-384/SHA-512, salt appended to the plaintext and to the resulting
Base64) is **`internal`** — reachable only from `Cryptography` and, via `InternalsVisibleTo`, from the test
project. It is not part of the public contract.

---

## Platform notes

| Concern | Detail |
|---|---|
| **Windows-only members** | `MachineIdentity`, `MachineIdentityValidator` are annotated `[SupportedOSPlatform("windows")]`. Guard calls with `OperatingSystem.IsWindows()` to stay CA1416-clean on a portable build (the demo does exactly this). |
| **Nullable / implicit usings** | Both **disabled** on this project — matching the ported legacy source. Callers with NRT enabled see no annotations. |
| **Encodings** | `RC4` string overloads use **UTF-16LE** (`Encoding.Unicode`); `Cryptography` uses **UTF-8**. Mixing them corrupts round-trips. `CharSetUtil` registers `CodePagesEncodingProvider` on each call. |
| **Threading** | Every public member is static and stateless — safe to call concurrently. The one mutable piece of shared state is the public `RC4.mHexKey` field; treat it as read-only. |

---

## Components & repository layout

```
Tssipl.Security.Cryptography/
├── TflSecurityCrypto.slnx              ← solution
├── TflSecurityCrypto/                  ← the library (net10.0)
│   ├── PasswordHash.cs                 ← modern password storage (PBKDF2)
│   ├── Cryptography.cs                 ← MD5 / Triple-DES / salted SHA-256
│   ├── SimpleHash.cs                   ← internal salted-hash engine (Obviex-derived)
│   ├── RC4.cs                          ← RC4 stream cipher + JS twin
│   ├── RNGCSP.cs                       ← cryptographic RNG helper
│   ├── CharSetUtil.cs                  ← CP1252 Chr()
│   ├── MachineIdentity.cs              ← WMI hardware fingerprint (Windows)
│   ├── MachineIdentityValidator.cs     ← licence-file validation (Windows)
│   ├── AppConfigSectionProtector.cs    ← PlatformNotSupportedException on .NET 10
│   └── ConfigFileProtection.cs         ← PlatformNotSupportedException on .NET 10
├── TflSecurityCrypto.Tests/            ← xUnit; sees internals via InternalsVisibleTo
│   ├── GoldenVectorTests.cs            ← byte-for-byte parity with the legacy VB output
│   ├── PasswordHashTests.cs            ← PBKDF2 invariants
│   ├── RoundTripTests.cs
│   ├── RngAndPlatformTests.cs
│   └── LicenseValidatorTests.cs
├── LegacyVb/                           ← compiles the ORIGINAL, unmodified legacy .vb source
└── Demo/                               ← runs both libraries side by side and diffs the output
```

`LegacyVb.vbproj` deliberately compiles the untouched legacy sources from `../../Tssipl.Security.Cryptography/`
(`Cryptography.vb`, `SimpleHash.vb`, `RC4.vb`, `MachineIdentity.vb`, `MachineIdentityValidator.vb`) with the
obsolete-API warnings suppressed. It exists purely as the **oracle** the port is measured against.

---

## Compatibility guarantee & how it is proven

The claim is specific: **for every ported primitive, the C#/.NET 10 output is byte-for-byte identical to the
legacy VB.NET/.NET Framework output.** It is enforced two ways.

**1 · Golden vectors** (`GoldenVectorTests.cs`) — expected values were captured by running the original,
unmodified `.vb` source, then frozen as test data:

| Primitive | Pinned cases |
|---|---|
| MD5 (`Encrypt(text)`) | 4 inputs incl. empty string and `unicode: café ☃ 日本語` |
| Triple-DES hashed key | the same 4 inputs |
| Triple-DES **un**hashed key | must throw, as the legacy did |
| RC4 | 2 key/data pairs; empty key must throw `DivideByZeroException` |
| Salted SHA-256 | 2 text/salt pairs |
| `SimpleHash` with a fixed salt | all 6 algorithm branches (MD5, SHA-1/256/384/512, and the unknown→MD5 fallback) |

**2 · The Demo** (`Demo/Program.cs`) — uses `extern alias` to load *both* assemblies at once and runs the same
inputs through each, printing a `MATCH`/`DIFFER` row per case and exiting non-zero on any mismatch. It also
proves genuine interop rather than mere equality:

- ciphertext produced by the legacy library decrypts with the new one, and vice versa;
- a licence issued by either library validates with the other on the same machine;
- a licence for a different machine is rejected by both.

`PasswordHash` has no legacy counterpart, so it is covered behaviourally instead (`PasswordHashTests.cs`):
correct password verifies, wrong one does not, salt differs per call, format is well-formed, tampered key fails,
malformed input returns `false` without throwing, and `NeedsRehash` flags missing / malformed / lower-iteration
values.

---

## Build, test, demo

```powershell
# Build the library (do this FIRST when consumers reference the DLL by HintPath)
dotnet build TflSecurityCrypto/TflSecurityCrypto.csproj

# Whole solution — library, tests, LegacyVb oracle, demo
dotnet build TflSecurityCrypto.slnx

# Tests
dotnet test TflSecurityCrypto.Tests/TflSecurityCrypto.Tests.csproj

# Side-by-side legacy-vs-new comparison; exit code 0 means every case matched
dotnet run --project Demo
```

The demo's machine-identity section is skipped automatically on non-Windows.

---

## How TrustBank CBS uses this library

| CBS call site | Member | Purpose |
|---|---|---|
| `TflCbs.Core.Authentication/AuthenticationService.cs` | `PasswordHash.Verify`, `PasswordHash.Create` | Login verification, and re-hash on the way through |
| `TflCbs.Core.Authentication/LoginRules.cs` | `PasswordHash.Verify` | Password-policy / history checks |
| `TflCbs.Core.Authentication.Web/Controllers/AccountController.cs` | `PasswordHash.Verify`, `Cryptography.Decrypt` | Change-password flow; decrypting a legacy value |
| `TflCbs.Tools.PasswordReset/Program.cs` | `PasswordHash.Create` | Administrative reset tool |
| `TflCbs.Modules.General/GeneralService.cs` | `Cryptography.Decrypt` | Reading a legacy-encrypted stored value |
| `TflCbs.Lab.Demo` (`Program.cs`, `Perf.cs`) | `Cryptography.Encrypt` | Proc-migration parity + perf harness |

All 1,731 CBS user records were migrated from the legacy reversible storage to `PasswordHash` — the migration
that closed the "reversible password storage" finding in the CBS architecture review.

---

## Further reading

| Document | What it covers |
|---|---|
| [docs/api-reference.md](docs/api-reference.md) | Every public member: signature, parameters, return, throws, notes |
| [docs/security-notes.md](docs/security-notes.md) | Which primitive is safe for what, key management, migration guidance, threat notes |
