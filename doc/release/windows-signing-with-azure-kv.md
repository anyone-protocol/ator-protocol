# Windows Binary Signing with Azure Key Vault

This document describes how to set up Windows code signing for the Anon client
binaries (`anon.exe`, `anon-gencert.exe`) using Azure Key Vault and AzureSignTool.

## Background

The signing action at `.github/actions/sign-windows/action.yml` uses
[AzureSignTool](https://github.com/vcsjones/AzureSignTool) to sign Windows
binaries with a certificate stored in Azure Key Vault. Timestamps are applied
via `http://timestamp.digicert.com`.

Two workflows invoke this action:

- `.github/workflows/build-windows.yml` — standalone Windows build (uses `ANYONE_AZURE_*` secrets)
- `.github/workflows/build-packages.yml` — full release pipeline (uses `ANYONE_AZURE_*` secrets)

## Prerequisites

- An Azure subscription with a Key Vault (Standard tier is sufficient for OV certs)
- Access to the Azure Portal or Azure CLI
- Admin access to the GitHub repository settings (for secrets)

## Step 1: Obtain a Code Signing Certificate

### Option A: Reissue from the original CA (preferred)

If the org still has access to the original Certificate Authority account:

1. Log into the CA's certificate management portal
2. Find the original code signing certificate order
3. Choose **Reissue** or **Rekey** — this is typically free and generates a new key pair
4. Download the reissued certificate as a `.pfx` (PKCS#12) bundle
5. Proceed to Step 2

### Option B: Generate a CSR from Azure Key Vault

This approach keeps the private key in Key Vault (it never leaves):

1. Azure Portal → Key Vault → **Certificates** → **Generate/Import**
2. Method: **Generate**
3. Certificate Name: e.g., `anon-code-signing`
4. Subject: `CN=Your Org Name`
5. Advanced Policy → Key type: RSA, Key size: 3072 or 4096
6. Click **Create** — this creates a pending certificate
7. Open the pending certificate → **Certificate Operation** → **Download CSR**
8. Submit the CSR to your chosen CA during the purchase/reissue process
9. Once the CA issues the signed certificate, return to the pending certificate →
   **Merge Signed Request** → upload the CA-signed cert
10. Proceed to Step 3 (skip Step 2)

### Option C: Purchase a new certificate

If the original CA account is also lost, purchase a new OV code signing certificate:

| CA | Approx. Price | Turnaround |
|---|---|---|
| DigiCert | ~$474/yr | 1–3 days |
| Sectigo (via resellers) | ~$189/yr | 1–5 days |
| GlobalSign | ~$249/yr | 1–3 days |
| SSL.com (via resellers) | ~$70/yr | 1–3 days |

The CA will require organization validation documents (business registration,
phone verification, etc.). Generate a CSR per Option B above, or generate
locally with OpenSSL:

```
openssl req -new -newkey rsa:3072 -nodes -keyout codesign.key -out codesign.csr
```

After receiving the signed cert, combine into a `.pfx`:

```
openssl pkcs12 -export -out codesign.pfx -inkey codesign.key -in cert.pem -certfile chain.pem
```

> **Note on EV certificates:** EV code signing certificates require HSM-backed
> key storage (Key Vault **Premium** tier). Standard tier only supports
> software-protected keys, which is sufficient for OV certificates.

## Step 2: Import the Certificate into Azure Key Vault

If you used Option B (CSR from Key Vault) in Step 1, skip this — the cert is
already in the vault.

1. Azure Portal → Key Vault → **Certificates** → **Generate/Import**
2. Method of creation: **Import**
3. Upload the `.pfx` file and enter its password
4. Certificate Name: e.g., `anon-code-signing`

> **Remember this name** — it becomes the `ANYONE_AZURE_CERT_NAME` secret value.

## Step 3: Create an Azure AD App Registration (Service Principal)

AzureSignTool authenticates to Key Vault using an Azure AD service principal.

1. Azure Portal → **Microsoft Entra ID** → **App registrations** → **New registration**
2. Name: e.g., `anon-code-signing-sp`
3. Supported account types: **Accounts in this organizational directory only**
4. Redirect URI: leave blank
5. Click **Register**

Note these values from the overview page:

| Field | Maps to Secret |
|---|---|
| Application (client) ID | `ANYONE_AZURE_CLIENT_ID` |
| Directory (tenant) ID | `ANYONE_AZURE_TENANT_ID` |

### Create a client secret

1. App registration → **Certificates & secrets** → **New client secret**
2. Description: e.g., `github-actions-signing`
3. Expiry: 12 or 24 months
4. Click **Add**
5. **Copy the Value immediately** (it is only shown once)

| Field | Maps to Secret |
|---|---|
| Client secret Value | `ANYONE_AZURE_CLIENT_SECRET` |

> **Set a calendar reminder** to rotate this secret before it expires.

## Step 4: Grant Key Vault Access to the Service Principal

### If the Key Vault uses Access Policies

1. Key Vault → **Access policies** → **Add Access Policy**
2. Configure permissions:
   - Key permissions: `Get`, `Sign`
   - Secret permissions: `Get`
   - Certificate permissions: `Get`
3. Select principal: search for the app registration name from Step 3
4. Click **Add**, then **Save**

### If the Key Vault uses Azure RBAC

1. Key Vault → **Access control (IAM)** → **Add role assignment**
2. Assign both roles to the service principal:
   - `Key Vault Crypto User`
   - `Key Vault Certificate User`

## Step 5: Note the Key Vault URI

Find the Key Vault URI on the Key Vault **Overview** page, e.g.:

```
https://your-vault-name.vault.azure.net/
```

| Field | Maps to Secret |
|---|---|
| Vault URI | `ANYONE_AZURE_KEY_VAULT_URI` |

## Step 6: Configure GitHub Secrets

Go to the GitHub repository → **Settings** → **Secrets and variables** → **Actions**.

Create or update these 5 repository secrets:

| Secret Name | Value Source |
|---|---|
| `ANYONE_AZURE_KEY_VAULT_URI` | Key Vault URI (Step 5) |
| `ANYONE_AZURE_CLIENT_ID` | Application (client) ID (Step 3) |
| `ANYONE_AZURE_TENANT_ID` | Directory (tenant) ID (Step 3) |
| `ANYONE_AZURE_CLIENT_SECRET` | Client secret Value (Step 3) |
| `ANYONE_AZURE_CERT_NAME` | Certificate name in Key Vault (Step 2) |

> **Do not delete** the old `AZURE_*` secrets — they remain for reference.

## Step 7: Verify

1. Trigger the `build-windows.yml` workflow manually via **workflow_dispatch**
2. Wait for the `sign-windows-64-binary` job to complete
3. Download the `anon-*-windows-signed-amd64` artifact
4. Verify the signature:
   - **Windows:** Right-click the `.exe` → Properties → Digital Signatures tab
   - **CLI:** `signtool verify /pa anon.exe`
5. Confirm the certificate subject matches your organization
