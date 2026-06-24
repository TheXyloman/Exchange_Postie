@echo off
setlocal

title Exchange Postie

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%Test-M365Connector.ps1"

if not exist "%SCRIPT_PATH%" (
    echo Could not find "%SCRIPT_PATH%".
    echo Keep this launcher in the same folder as Test-M365Connector.ps1.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo Exchange Postie finished successfully.
) else (
    echo Exchange Postie finished with exit code %EXIT_CODE%.
)
echo.
pause
exit /b %EXIT_CODE%
