# TflSecurityCrypto — API Reference

Every public member of the `TflSecurityCrypto` assembly (namespace `TflSecurityCrypto`, TFM `net10.0`).
All types are static-method containers; nothing needs instantiating. See [../README.md](../README.md) for
orientation and [security-notes.md](security-notes.md) for which primitive is appropriate where.

Legend — **Current**: use for new work · **Legacy**: compatibility only · **Unsupported**: throws on .NET 10.

---

## `PasswordHash` — static class · **Current**

PBKDF2-HMAC-SHA256 password storage. One-way; no decrypt exists.

### Constants

| Member | Type | Value | Meaning |
|---|---|---|---|
| `CurrentVersion` | `const string` | `"v1"` | Format tag written into every new hash. Only this version is accepted when parsing. |
| `CurrentIterations` | `const int` | `600000` | Iterations used by `Create` and the threshold used by `NeedsRehash`. |

Internal parameters (not public, stated for auditability): salt 16 bytes, derived key 32 bytes, PRF SHA-256,
separator `'$'`.

### `static string Create(string password)`

Generates a cryptographically random 16-byte salt, derives a 32-byte key with `Rfc2898DeriveBytes.Pbkdf2`, and
returns `v1$<iterations>$<base64 salt>$<base64 key>`.

- **Throws** `ArgumentNullException` when `password` is `null`. An **empty string is valid** and hashes normally.
- Non-deterministic by design: same password ⇒ different output each call.
- Cost: ~600k SHA-256 rounds — deliberately slow (tens of milliseconds). Do not call it in a loop over a batch.

### `static bool Verify(string password, string storedHash)`

Parses `storedHash`, re-derives with the embedded salt/iterations/key-length, compares with
`CryptographicOperations.FixedTimeEquals`.

- Returns `false` — **never throws** — for `null` password, or a `storedHash` that is null, empty, has ≠ 4
  fields, carries a version other than `v1`, has a non-numeric or non-positive iteration count, or invalid Base64.
- Constant-time comparison: no early exit that could leak byte positions by timing.

### `static bool NeedsRehash(string storedHash)`

`true` when the stored value cannot be parsed at all (missing / malformed / non-current version) **or** its
iteration count is below `CurrentIterations`. Intended use — right after a successful `Verify`:

```csharp
if (PasswordHash.Verify(submitted, stored) )
{
    if (PasswordHash.NeedsRehash(stored))
        SaveNewHash(PasswordHash.Create(submitted));   // silent cost upgrade
    SignIn();
}
```

---

## `Cryptography` — class (static members) · **Legacy**

Ported 1:1 from the legacy VB.NET implementation; output is byte-for-byte identical.

### `static byte[] Encrypt(string text)`

Raw **MD5** of the UTF-8 bytes of `text`. Unsalted, 16 bytes. Compatibility only — see
[security-notes.md](security-notes.md#md5-cryptographyencryptstring).

### `static string Encrypt(string toEncrypt, bool useHashing)`

**Triple-DES**, `CipherMode.ECB`, `PaddingMode.PKCS7`, over UTF-8 bytes; result Base64.

| `useHashing` | Key material | Result |
|---|---|---|
| `true` | MD5 of the key string → 16 bytes (two-key 3DES) | Works. This is the path in use. |
| `false` | Raw UTF-8 bytes of the key string | The built-in default key is 14 bytes — invalid for 3DES, so this **throws**. Matches legacy behaviour. |

Key resolution: `ConfigurationManager.AppSettings["SecurityKey"]` if non-empty, otherwise a hard-coded default
literal in `Cryptography.cs`. On hosts without an `app.config` (i.e. any ASP.NET Core app) the default is always used.

### `static string Decrypt(string cipherString, bool useHashing)`

Inverse of the above. `cipherString` must be Base64; invalid Base64 throws `FormatException`, and a wrong key
throws `CryptographicException` (bad PKCS7 padding). Neither is caught internally — the method rethrows.

### `static byte[] Encrypt(string text, string salt)`

Salted **SHA-256**. Appends a fixed suffix literal to `salt`, calls the internal `SimpleHash.ComputeHash(text,
"SHA256", saltBytes)`, and returns the **UTF-8 bytes of the resulting Base64 string** (not the raw digest — a
legacy quirk preserved deliberately).

### `static bool VerifyHash(string text, string salt)`

Recomputes the salted SHA-256 for `text` and verifies it. Note the legacy semantics: it hashes `text` and then
verifies that same freshly computed hash, so it answers "is this hash self-consistent", not "does this match a
stored value". To check a candidate against a stored hash, compare `Encrypt(text, salt)` to the stored bytes.

---

## `RC4` — sealed class (static members, private constructor) · **Legacy**

| Member | Signature | Notes |
|---|---|---|
| `mHexKey` | `public static string` | Shared hex key suffix, mirrored in the JS twin. Public and mutable — treat as read-only. |
| `GetRandomKey` | `static string GetRandomKey()` | `Guid.NewGuid().ToString()`. |
| `Encrypt` | `static string Encrypt(string key, string data)` | UTF-16LE (`Encoding.Unicode`) bytes, RC4, then Base64. |
| `Decrypt` | `static string Decrypt(string key, string data)` | Base64-decode, RC4, UTF-16LE decode. |
| `Encrypt` / `Decrypt` | `static byte[] …(byte[] key, byte[] data)` | Identical transform — RC4 is its own inverse. |
| `GetJsModuleScript` | `static string GetJsModuleScript()` | Minified JavaScript module (`RC4.rc4Encrypt` + `RC4.encode64`) so a browser can produce the same ciphertext. |

**Throws** `DivideByZeroException` for an empty key (`key[i % key.Length]` with length 0) — legacy behaviour,
pinned by test.

---

## `RNGCSP` — class (static members) · **Current**

### `static byte RollDice(byte numberSides)`

Uniform random value in `1..numberSides` from `RandomNumberGenerator`, using rejection sampling: bytes at or
above `numberSides * (255 / numberSides)` are discarded so the modulo does not skew the distribution.

- **Throws** `ArgumentOutOfRangeException` when `numberSides <= 0`.
- Suitable wherever a small uniform random integer is needed; for anything larger use
  `RandomNumberGenerator.GetInt32` directly.

---

## `CharSetUtil` — class (static members) · Utility

### `static string Chr(int p_intByte)`

Code-page-1252 single-byte → string, the VB `Chr()` equivalent. Registers `CodePagesEncodingProvider` on each
call. **Throws** `ArgumentOutOfRangeException` outside `0..255`.

---

## `MachineIdentity` — class (static members) · **Legacy** · Windows only

`[SupportedOSPlatform("windows")]`. WMI queries via `System.Management`. Every member propagates the underlying
`ManagementException` on failure.

| Member | Returns |
|---|---|
| `GetWin32_BaseBoard_SerialNumber()` | Motherboard serial (`Win32_BaseBoard.SerialNumber`) |
| `GetWin32_Processor_ProcessorId()` | CPU id (`Win32_Processor.ProcessorId`) |
| `GetWin32_LogicalDisk_VolumeSerialNumber()` | Volume serial of `c:` |
| `GetVolumeSerialNumber(string driveLetter)` | Volume serial of the given drive (e.g. `"d:"`); `""` if not found |
| `GetWin32_NetworkAdapterConfiguration_MacAddress()` | First MAC address |

### `static string GenerateKey()`

Composes a three-line `key=value` block (baseboard serial, C: volume serial, processor id) and returns
`Cryptography.Encrypt(block, useHashing: true)` — i.e. the Triple-DES ciphertext of the machine fingerprint.

---

## `MachineIdentityValidator` — class (static members) · **Legacy** · Windows only

### `static bool ValidateMachineIdentity(string licenseFile)`

Reads the licence file and validates it against this machine.

1. **Fail-open guard** — if `MachineIdentity.GenerateKey()` throws (no WMI, non-Windows, restricted service
   account), the method returns **`true`**. Preserved legacy behaviour; do not rely on it as a security control.
2. **Expiry prefix** — if the content starts with the fixed date-time marker, the following 24 characters decrypt
   to `yyyyMMdd`; past that date it throws `ApplicationException("License expired")`.
3. **Trial window** — if the decrypted payload contains `TRIAL`, the leading `$`-terminated segment is parsed as
   `…,<startDate>,<days>`; outside the window it rewrites the licence file and throws
   `ApplicationException("License file expired.")`.
4. **Machine binding** — decrypts the remaining payload a second time and compares with this machine's decrypted
   key. Mismatch ⇒ `false`; match ⇒ `true`.

Other exceptions surface as thrown: `FileNotFoundException`, `FormatException` (bad Base64), `CryptographicException`
(wrong key), `FormatException` from `DateTime.ParseExact`.

---

## `AppConfigSectionProtector` — class (static members) · **Unsupported on .NET 10**

| Member | Behaviour |
|---|---|
| `static void ProtectConnectionString(string exePath)` | Throws `PlatformNotSupportedException` |
| `static void UnprotectConnectionString(string exePath)` | Throws `PlatformNotSupportedException` |

Protected-configuration providers (`DataProtectionConfigurationProvider`) are not supported by
`System.Configuration` on .NET (Core) 5+. Use `System.Security.Cryptography.ProtectedData` instead.

---

## `ConfigFileProtection` — class (static members) · **Unsupported on .NET 10**

| Member | Behaviour |
|---|---|
| `static void ProtectSection(string sectionName, string provider, string applicationPath)` | Throws `PlatformNotSupportedException` |
| `static void UnProtectSection(string sectionName, string applicationPath)` | Throws `PlatformNotSupportedException` |

`System.Web.Configuration.WebConfigurationManager` does not exist on .NET (Core). Use ASP.NET Core Data
Protection or an external secret store.

---

## `SimpleHash` — **internal**, documented for completeness

Not part of the public API; visible to `TflSecurityCrypto.Tests` via `InternalsVisibleTo`. Derived from the
Obviex sample the legacy VB library used.

- `static string ComputeHash(string plainText, string hashAlgorithm, byte[] saltBytes)` — appends the salt to the
  UTF-8 plaintext, hashes with `MD5` / `SHA1` / `SHA256` / `SHA384` / `SHA512` (case-insensitive; **anything
  unrecognised falls back to MD5**), then returns Base64 of `hash || salt`. A `null` salt generates a random
  4–7-byte non-zero salt.
- `static bool VerifyHash(string plainText, string hashAlgorithm, string hashValue)` — recovers the salt from the
  tail of `hashValue` (using the algorithm's known digest length), recomputes, and compares.

---

## Exception summary

| Exception | Raised by |
|---|---|
| `ArgumentNullException` | `PasswordHash.Create(null)` |
| `ArgumentOutOfRangeException` | `RNGCSP.RollDice(<= 0)`, `CharSetUtil.Chr` outside 0–255 |
| `DivideByZeroException` | `RC4` with an empty key |
| `CryptographicException` | `Cryptography.Decrypt` with the wrong key (PKCS7 padding failure) |
| `FormatException` | `Cryptography.Decrypt` / `RC4.Decrypt` with non-Base64 input |
| `ApplicationException` | `MachineIdentityValidator` — expired licence or expired trial |
| `PlatformNotSupportedException` | Both config-protection types, every member |
| *(any)* | `Cryptography.Encrypt(text, useHashing: false)` — invalid 3DES key size |

`PasswordHash.Verify` and `PasswordHash.NeedsRehash` are the only members guaranteed never to throw on malformed
input.
