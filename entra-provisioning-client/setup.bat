@echo off
title Entra ID Provisioning Client - Setup
echo.
echo  ============================================
echo   Entra ID Provisioning Client - Local Setup
echo  ============================================
echo.

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Node.js is not installed.
    echo  Please install Node.js 18+ from https://nodejs.org
    echo.
    pause
    exit /b 1
)

for /f "tokens=1,2,3 delims=." %%a in ('node -v') do set NODE_MAJOR=%%a
set NODE_MAJOR=%NODE_MAJOR:v=%
if %NODE_MAJOR% lss 18 (
    echo  [ERROR] Node.js 18+ is required. Current: %NODE_MAJOR%
    echo  Please update from https://nodejs.org
    echo.
    pause
    exit /b 1
)

echo  [OK] Node.js found: 
node -v
echo.

:: Install dependencies
echo  [1/3] Installing server dependencies...
call npm install
if %errorlevel% neq 0 (
    echo  [ERROR] Failed to install server dependencies.
    pause
    exit /b 1
)

echo.
echo  [2/3] Installing client dependencies...
cd client
call npm install
if %errorlevel% neq 0 (
    echo  [ERROR] Failed to install client dependencies.
    pause
    exit /b 1
)

echo.
echo  [3/3] Building client...
call npx react-scripts build
if %errorlevel% neq 0 (
    echo  [ERROR] Failed to build client.
    pause
    exit /b 1
)

cd ..

echo.
echo  ============================================
echo   Setup complete!
echo  ============================================
echo.
echo   To start the app, run:
echo     npm start
echo.
echo   Then open http://localhost:3001 in your browser.
echo.
echo   All credentials stay on your local machine.
echo   No data is sent to any cloud service until
echo   you explicitly click "Send" in the final step.
echo.
pause
