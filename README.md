<p align="center">
  <img src="ExchangePostie_Logo.png" alt="Exchange Postie" width="180">
</p>

# Exchange Postie

A small PowerShell tool for testing Microsoft 365 mail flow connector paths.

## What it does

Exchange Postie sends a plain text test message through either a Microsoft 365 MX host or authenticated SMTP submission. The test message uses this subject:

```text
M365 Mail Flow Connector Test from the Exchange Postie
```

It supports both a guided prompt flow and repeatable command-line use. Each run starts with an Exchange Postie ASCII banner, shows the selected SMTP path, then reports whether the SMTP server accepted the message.

## Setup

1. Download or clone this repository.
2. Keep the files together in the existing folder layout.
3. Open `Exchange Postie Files`.
4. Double-click `Launch-ExchangePostie.cmd` to start the guided prompt flow.

The repository layout is:

```text
README.md
ExchangePostie_Logo.png
Exchange Postie Files\
  ExchangePostie_Core.ps1
  Launch-ExchangePostie.cmd
  ExchangePostie.ico
```

## Launcher

`Launch-ExchangePostie.cmd` is the normal way to run Exchange Postie interactively. It launches `ExchangePostie_Core.ps1` from the same folder, passes through any command-line arguments, and pauses at the end so the result stays visible.

The launcher is a plain text Windows command file, not a compiled executable. It starts PowerShell with a process-scoped execution policy bypass so the script can run without changing the machine-wide execution policy.

Some managed devices may still block scripts or command files through company security policy, but this avoids the higher-friction `.exe` packaging route that often attracts signing and antivirus scrutiny.

## How the files work

`Launch-ExchangePostie.cmd` is a small wrapper for Windows users. It:

- Finds the folder it is running from.
- Looks for `ExchangePostie_Core.ps1` in that same folder.
- Shows a clear error if the PowerShell script is missing.
- Starts PowerShell with `-NoLogo`, `-NoProfile`, and `-ExecutionPolicy Bypass` for that one process.
- Passes any extra arguments through to `ExchangePostie_Core.ps1`.
- Captures the script exit code and reports whether Exchange Postie finished successfully.
- Pauses before closing so the result remains visible when launched by double-click.

`ExchangePostie_Core.ps1` is the actual Exchange Postie test script. It:

- Accepts SMTP test settings through parameters or asks for them in a guided prompt flow.
- Validates the sender and recipient addresses before sending.
- Supports unauthenticated connector testing against the supplied Microsoft 365 MX host.
- Supports authenticated SMTP submission using `smtp.office365.com`.
- Uses port `25` by default for unauthenticated tests and port `587` by default for authenticated tests.
- Enables TLS/STARTTLS by default unless `-DisableTls` is used.
- Sends a plain text Microsoft 365 mail flow connector test message.
- Prints a summary of the target host, port, TLS setting, authentication mode, sender, recipient, and subject.
- Exits with code `0` when the SMTP server accepts the message and code `1` when the test fails.

## Files

| File | Purpose |
| --- | --- |
| `Exchange Postie Files\Launch-ExchangePostie.cmd` | Double-click launcher for the guided flow. |
| `Exchange Postie Files\ExchangePostie_Core.ps1` | Main PowerShell script that sends the SMTP test message. |
| `Exchange Postie Files\ExchangePostie.ico` | Icon asset kept with the tool files. |
| `ExchangePostie_Logo.png` | Logo used by this README. |

## Examples

Run a standard unauthenticated connector test against a Microsoft 365 MX host:

```powershell
.\ExchangePostie_Core.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com
```

Run the guided prompt flow from inside `Exchange Postie Files`:

```powershell
.\Launch-ExchangePostie.cmd
```

Run an authenticated SMTP submission test:

```powershell
.\ExchangePostie_Core.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com -UseCredentials
```

When credentials are used, the SMTP target is `smtp.office365.com` and the default port is `587`.

Disable TLS/STARTTLS if you need to test a non-TLS path:

```powershell
.\ExchangePostie_Core.ps1 -Host contoso-com.mail.protection.outlook.com -From sender@contoso.com -To recipient@contoso.com -DisableTls
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
