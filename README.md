<p align="center">
  <img src="ExchangePostie_Logo.png" alt="Exchange Postie" width="180">
</p>

# Exchange Postie

A small PowerShell tool for testing Microsoft 365 mail flow connector paths.

## Tool

`Test-M365Connector.ps1` sends a plain text test message with this subject:

```text
M365 Mail Flow Connector Test from the Exchange Postie
```

It supports both guided prompts and repeatable command-line use.
Each run starts with an Exchange Postie ASCII banner and a clean summary of the selected SMTP path.

## Double-click launch

From the parent folder, double-click `Exchange Postie.lnk` to run the guided prompt flow in a normal console window.

The visible package layout is:

```text
Exchange Postie.lnk
Exchange Postie Files\
```

Keep `Exchange Postie.lnk` next to the `Exchange Postie Files` folder. The shortcut launches `Exchange Postie Files\Launch-ExchangePostie.cmd` and uses `Exchange Postie Files\ExchangePostie.ico` as its icon.

The launcher is a plain text Windows command file, not a compiled executable. It starts PowerShell with a process-scoped execution policy bypass so the script does not need to be code-signed, and it pauses at the end so the result stays visible.

Some managed devices may still block scripts or command files through company security policy, but this avoids the higher-friction `.exe` packaging route that often attracts signing and antivirus scrutiny.

If the package is moved or extracted somewhere else, recreate the root shortcut from inside `Exchange Postie Files`:

```powershell
.\Create-ExchangePostieShortcut.ps1
```

## Examples

Run a standard unauthenticated connector test against a Microsoft 365 MX host:

```powershell
.\Test-M365Connector.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com
```

Run the guided prompt flow:

```powershell
.\Test-M365Connector.ps1
```

Run an authenticated SMTP submission test:

```powershell
.\Test-M365Connector.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com -UseCredentials
```

When credentials are used, the SMTP target is `smtp.office365.com` and the default port is `587`.

Disable TLS/STARTTLS if you need to test a non-TLS path:

```powershell
.\Test-M365Connector.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com -DisableTls
```

## Parameters

| Parameter | Description |
| --- | --- |
| `-Host` | SMTP host or Microsoft 365 MX record, such as `contoso-com.mail.protection.outlook.com`. Internally this is an alias for `-SmtpHost` because `$Host` is a PowerShell automatic variable. |
| `-From` | Sender address for the test message. |
| `-To` | Recipient address for the test message. |
| `-UseCredentials` | Enables authenticated SMTP submission. |
| `-Credential` | Supplies a `PSCredential`. If omitted with `-UseCredentials`, the script prompts using `Get-Credential`. |
| `-Port` | SMTP port. Only `25` and `587` are accepted. Defaults to `25` without credentials and `587` with credentials. |
| `-DisableTls` | Turns off TLS/STARTTLS. TLS is enabled by default. |

## Defaults

- Without credentials: uses the entered `-Host`, port `25`, and TLS enabled.
- With credentials: uses `smtp.office365.com`, port `587`, and TLS enabled.
- Success exits with code `0`; failure exits with code `1` and prints a short error summary.
