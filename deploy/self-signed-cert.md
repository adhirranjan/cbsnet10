# Self-Signed HTTPS Certificate for CBS on IIS (this machine)

How the CBS IIS deployment gets HTTPS **without a public CA** — create a self-signed certificate, trust it, and bind it to the site(s). This is the exact procedure used by the single-host deploy (`cbs-single`, port 8081) and is reused unchanged by the future multi-host sites.

> Self-signed = fine for a **local / internal** machine (dev, demo, LAN). For an internet-facing box use a real CA cert instead. All commands below run in an **elevated** PowerShell (Administrator).

## 0. Why one cert for every CBS site

We create **one** certificate whose Subject Alternative Names cover every name the browser/`curl`/the gateway will use on this box — `localhost`, the machine name `COM40`, and `127.0.0.1`. Because the SANs cover all of them, the *same* cert is bound to every CBS https binding (`cbs-single:8081` now; `cbs-gateway:8101`, `cbs-default:8111`, … later). One cert to create, trust, and eventually renew.

## 1. Create the certificate

```powershell
$cert = New-SelfSignedCertificate `
  -DnsName 'localhost','COM40','127.0.0.1' `
  -CertStoreLocation 'Cert:\LocalMachine\My' `
  -FriendlyName 'TrustBankCBS-SelfSigned' `
  -KeyExportPolicy Exportable `
  -KeyUsage DigitalSignature, KeyEncipherment `
  -KeyAlgorithm RSA -KeyLength 2048 `
  -NotAfter (Get-Date).AddYears(5)

$cert.Thumbprint   # e.g. A1B2C3...  — you need this to bind
```

- Lands in **`LocalMachine\My`** (the machine's *Personal* store) — where IIS/HTTP.SYS looks for SSL binding certs. (Not `CurrentUser`.)
- `-FriendlyName 'TrustBankCBS-SelfSigned'` makes it easy to find later and distinguishes it from the other `localhost` certs already on this box.
- `-NotAfter (5 years)` avoids the 1-year default expiring mid-use.

Re-find it any time by friendly name:

```powershell
$cert = Get-ChildItem Cert:\LocalMachine\My |
        Where-Object FriendlyName -eq 'TrustBankCBS-SelfSigned' |
        Select-Object -First 1
```

## 2. Trust the certificate (install into Trusted Root)

A self-signed cert isn't trusted by anything yet, so browsers and `curl` show a warning. To make it **trusted on this machine**, copy the (public) cert into the machine's **Trusted Root Certification Authorities** store:

```powershell
$root = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine')
$root.Open('ReadWrite')
$root.Add($cert)          # public cert only — no private key leaves My
$root.Close()
```

After this, `https://localhost:8081/` opens **without** a warning in browsers on this machine, and `curl https://localhost:8081/health` works **without** `-k`.

- **Alternative (skip trust):** don't import to Root and just accept the browser warning / use `curl -k`. Fine for a throwaway demo; do the Root import for a clean experience.
- To trust it on *another* machine (e.g. a client hitting this server): export the public cert and import it into that machine's `LocalMachine\Root` (§4).

## 3. Use it — bind to the IIS site's https binding

IIS/HTTP.SYS binds a cert to an **IP:port** (SNI optional). For a CBS site on https port `8081`:

```powershell
Import-Module WebAdministration

# ensure the https binding exists on the site
New-WebBinding -Name 'cbs-single' -Protocol https -Port 8081 -IPAddress '*'

# attach the cert to that binding (thumbprint from §1, store 'My')
(Get-WebBinding -Name 'cbs-single' -Protocol https -Port 8081).AddSslCertificate($cert.Thumbprint, 'My')
```

Equivalent low-level form (no WebAdministration), binds to all IPs on the port:

```powershell
netsh http add sslcert ipport=0.0.0.0:8081 certhash=$($cert.Thumbprint) `
      appid='{00112233-4455-6677-8899-aabbccddeeff}' certstorename=MY
```

Reuse the **same** `$cert.Thumbprint` for every CBS site's https port (8101/8111/8121/8131/8141/8151) — the SANs already cover the hostnames.

## 4. Verify

```powershell
# binding is present with a cert hash:
netsh http show sslcert ipport=0.0.0.0:8081

# trusted (no -k needed once §2 is done):
curl.exe https://localhost:8081/health          # 200 Healthy
# still works ignoring trust:
curl.exe -k https://localhost:8081/health
```

Browser: `https://localhost:8081/` → padlock (after §2), or a one-time warning (without §2).

Export the public cert (to trust on other machines):

```powershell
Export-Certificate -Cert $cert -FilePath 'D:\publish\TrustBankCBS-SelfSigned.cer'
# on the other machine: Import-Certificate -FilePath ...\TrustBankCBS-SelfSigned.cer -CertStoreLocation Cert:\LocalMachine\Root
```

## 5. Renew (before expiry)

Repeat §1 (new cert), then re-run §2 (trust) and §3 (re-bind with the **new** thumbprint) for every site. Then delete the old one (§6). Set a reminder ~1 month before `NotAfter`.

## 6. Rollback / remove

```powershell
$t = $cert.Thumbprint
netsh http delete sslcert ipport=0.0.0.0:8081                 # (repeat per bound port)
Remove-Item "Cert:\LocalMachine\My\$t"   -Force
Remove-Item "Cert:\LocalMachine\Root\$t" -Force               # only the one we added
```

## Notes

- **Store matters:** the SSL cert must be in `LocalMachine\My` (HTTP.SYS reads machine stores; an app-pool identity can't use a `CurrentUser` cert).
- **HTTP still open:** the sites also bind plain http (single host: 8080). `UseHttpsRedirection` bounces http→https; `/health` answers on either.
- **`Auth:Cookie:SecurePolicy`** is `SameAsRequest` (base config) — the `CbsAuth` cookie is marked `Secure` when served over https (8081). For an https-only posture set it to `Always`.
- Related: [iis-single-host.md](iis-single-host.md) (§4 binding), [iis-multi-host.md](iis-multi-host.md) (per-site bindings — reuse this same cert).
