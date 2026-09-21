@echo off
title billAnaly - One-Click Start

cd /d "%~dp0"

echo ============================================================
echo               billAnaly - One-Click Start
echo ============================================================
echo.

set "VENV_PY=venv\Scripts\python.exe"

REM pip mirror - faster downloads in China. Remove "-i %MIRROR%" to use default PyPI.
set "MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple"

REM ================= 1. Python interpreter =================
if exist "%VENV_PY%" goto :step_deps

echo [1/5] First run: creating virtual environment...

set "PYCMD="
py -3.13 -c "import sys" >nul 2>nul
if not errorlevel 1 set "PYCMD=py -3.13"
if defined PYCMD goto :make_venv

py -3 -c "import sys" >nul 2>nul
if not errorlevel 1 set "PYCMD=py -3"
if defined PYCMD goto :make_venv

python -c "import sys" >nul 2>nul
if not errorlevel 1 set "PYCMD=python"
if defined PYCMD goto :make_venv

echo.
echo [ERROR] No usable Python found.
echo.
echo         Please install Python 3.10 or newer:
echo         https://www.python.org/downloads/
echo         Make sure to tick "Add Python to PATH" during setup.
echo.
pause
exit /b 1

:make_venv
%PYCMD% -m venv venv
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to create the virtual environment.
    pause
    exit /b 1
)
echo       Virtual environment created.
goto :step_deps

REM ================= 2. Dependencies =================
:step_deps
"%VENV_PY%" -c "import fastapi,uvicorn,openai,yaml,pandas,matplotlib,numpy" >nul 2>nul
if not errorlevel 1 goto :step_config

echo [2/5] Installing dependencies (the first run can take a few minutes)...
"%VENV_PY%" -m pip install --upgrade pip -i %MIRROR%
"%VENV_PY%" -m pip install -r requirements.txt -i %MIRROR%
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install dependencies. Check your network and retry.
    pause
    exit /b 1
)
echo       Dependencies installed.
goto :step_config

REM ================= 3. Configuration =================
:step_config
if not exist "config.yaml" (
    echo [3/5] config.yaml not found, copying from config-example.yaml...
    copy "config-example.yaml" "config.yaml" >nul
    echo       Created. Remember to fill in your DeepSeek API Key.
    goto :step_port
)

findstr /C:"sk-" "config.yaml" >nul 2>nul
if errorlevel 1 (
    echo.
    echo [NOTE] No DeepSeek API Key found in config.yaml.
    echo        Bookkeeping and charts still work, but AI features will fail.
    echo.
    goto :step_port
)
echo [3/5] config.yaml OK.

REM ================= 4. Port check =================
:step_port
netstat -ano | findstr ":8000" | findstr "LISTENING" >nul 2>nul
if not errorlevel 1 (
    echo.
    echo [NOTE] Port 8000 is already in use - the service may already be running.
    echo        Opening the browser now.
    echo        To restart, close the existing service window first.
    echo.
    start "" http://localhost:8000/manager.html
    timeout /t 3 /nobreak >nul
    exit /b 0
)

REM ================= 5. Start the service =================
echo [5/5] Starting the service...
echo.
echo    Manager  : http://localhost:8000/manager.html
echo    Dashboard: http://localhost:8000/dashboard.html
echo.
echo    The two pages link to each other at the top.
echo    The service runs in a separate window - close it to stop the service.
echo.

REM The service window uses UTF-8, otherwise the emoji printed by server.py
REM crashes on the default GBK code page of Chinese Windows.
start "billAnaly server" cmd /k "chcp 65001 >nul && set PYTHONIOENCODING=utf-8 && venv\Scripts\python.exe server.py"

echo    Waiting for the service to start...
timeout /t 7 /nobreak >nul
start "" http://localhost:8000/manager.html

echo.
echo    Browser opened on the Manager page. This window can be closed.
echo    After adding records, click the Dashboard link at the top of that page.
timeout /t 6 /nobreak >nul
exit /b 0
