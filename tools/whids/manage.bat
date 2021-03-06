@echo off

set BASENAME=Whids.exe
set INSTALL_DIR=%programfiles%\Whids
set UNINSTALL_SCRIPT=%INSTALL_DIR%\Uninstall.bat
set BINPATH=%INSTALL_DIR%\%BASENAME%
set CONFIG=%INSTALL_DIR%\config.json
REM default during installation used to clean
set ALERTS=%INSTALL_DIR%\Logs\Alerts
set DUMPS=%INSTALL_DIR%\Dumps
set VERSION="REPLACED BY MAKEFILE"
set SVC=Whids
set SYSMON=Sysmon64

set RULES_IMPORT="%~dp0\rules"

:choice
echo [i]  Install WHIDS from scratch (removes older installation)
echo [un] Uninstall previous installation
echo [up] Update WHIDS binary (keeps current config)
echo [st] Start services
echo [sp] Stop services
echo [r]  Restart services
echo [g]  Remove alerts logs and dumps
echo [gr] Remove alerts logs and dumps and restart
echo [e]  Edit WHIDS configuration
echo [c]  Clear screen
echo [q]  Quit
echo.
SET /P _ch= "Please select option:"
IF "%_ch%"=="i" (
    call :StopSvcs
    call :Uninstall
    call :Install
    call :CreateWhidsSvc
    call :ImportRules
    call :GenUninstall
    call :PromptStartSvcs
)
IF "%_ch%"=="un" (
    call :Uninstall
)
IF "%_ch%"=="up" (
    call :StopSvcs
    call :CopyBin
    call :PromptStartSvcs
)
IF "%_ch%"=="st" (
    call :StartSvcs
)
IF "%_ch%"=="sp" (
    call :StopSvcs
)
IF "%_ch%"=="r" (
    call :StopSvcs
    call :StartSvcs
)
IF "%_ch%"=="g" (
    call :Groom
)
IF "%_ch%"=="gr" (
    call :StopSvcs
    call :Groom
    call :StartSvcs
)
IF "%_ch%"=="e" (
    notepad "%CONFIG%"
    cls
)
IF "%_ch%"=="c" (
    cls
)
IF "%_ch%"=="q" (
    EXIT 0
)
echo.
GOTO :choice

:Groom
IF exist "%ALERTS%" (
    echo.
    echo [+] Removing directory: "%ALERTS%"
    rmdir /S /Q "%ALERTS%"
)
IF exist "%DUMPS%" (
    echo [+] Removing directory: "%DUMPS%"
    rmdir /S /Q "%DUMPS%"
    echo.
)
EXIT /B 0

:Uninstall
echo.
IF exist "%UNINSTALL_SCRIPT%" (
    echo [+] Running uninstallation script
    cmd /c "%UNINSTALL_SCRIPT%"
    echo [+] Uninstallation finished
)
EXIT /B 0

:CopyBin
echo [+] Installing %BASENAME% (%PROCESSOR_ARCHITECTURE%) in %INSTALL_DIR%
if %PROCESSOR_ARCHITECTURE%==AMD64 (
    echo F | xcopy /Y /X "%~dp0whids-v%VERSION%-amd64.exe" "%BINPATH%"
) else (
    echo F | xcopy /Y /X "%~dp0whids-v%VERSION%-386.exe" "%BINPATH%"
)
EXIT /B 0

:Install
echo.
echo [+] Creating Installation Directory: %INSTALL_DIR%
mkdir "%INSTALL_DIR%"

call :CopyBin

echo [+] Setting up rights to installation directory
icacls "%INSTALL_DIR%" /inheritance:r /grant:r Administrators:(OI)(CI)F /grant:r SYSTEM:(OI)(CI)F

echo [+] Installing default configuration file
"%BINPATH%" -dump-conf > "%CONFIG%"
EXIT /B 0

:ImportRules
:ask_import
echo.
SET /P _input= "[+] Do you want to import detection rules shipped with project [Y/N]:"
IF "%_input%"=="Y" GOTO :import
IF "%_input%"=="N" GOTO :end_import
GOTO :ask_import
:import
"%BINPATH%" -import "%RULES_IMPORT%"
:end_import
EXIT /B 0

:CreateWhidsSvc
echo.
echo [+] Creating WHIDS service
sc.exe create %SVC% binPath= "%BINPATH%" start= auto
sc.exe description %SVC% "Windows Host IDS (v%VERSION%)"

echo [+] Making Sysmon service (%SYSMON%) depending on WHIDS in order to catch all events at boot
sc.exe config %SYSMON% depend= %SVC%
EXIT /B 0

:GenUninstall 
echo.
echo [+] Generating Uninstall Script
echo @echo off > "%UNINSTALL_SCRIPT%"
echo cd "%PROGRAMFILES%" >> "%UNINSTALL_SCRIPT%"
echo sc.exe config %SYSMON% depend= "" >> "%UNINSTALL_SCRIPT%"
echo net.exe stop %SVC% /yes >> "%UNINSTALL_SCRIPT%"
echo sc.exe delete %SVC% >> "%UNINSTALL_SCRIPT%"
echo timeout 10 >> "%UNINSTALL_SCRIPT%"
echo cmd /c rmdir /S /Q "%INSTALL_DIR%" >> "%UNINSTALL_SCRIPT%"
EXIT /B 0

:StartSvcs
echo.
echo [+] Running %SVC% service
net.exe start %SVC%
echo [+] Running %SYSMON% service
net.exe start %SYSMON%
EXIT /B 0

:PromptStartSvcs
echo.
:ask_start
SET /P _input= "[+] Do you want to start services (Whids + Sysmon) [Y/N]:"
IF "%_input%"=="Y" GOTO :start
IF "%_input%"=="N" GOTO :end_start
GOTO :ask_start
:start
call :StartSvcs
:end_start
EXIT /B 0

:StopSvcs
echo.
echo [+] Stopping %SVC% service
net.exe stop %SVC% /yes
EXIT /B 0