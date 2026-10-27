@echo off
rem Autopilot test: pull latest code, build the race place with the AutoTest flag, open it in Studio.
rem Then press F5 in Studio: the bot drives the track and prints [AutoTest] lines to Output and the Studio log.
cd /d "%~dp0"

set BRANCH=%1
if "%BRANCH%"=="" set BRANCH=claude/project-thread-bryscd

git fetch origin
git checkout %BRANCH% || git checkout -b %BRANCH% origin/%BRANCH%
git pull origin %BRANCH%

if not exist build mkdir build
rojo build autotest.project.json -o build\autotest.rbxl
if errorlevel 1 (
	echo Build failed, not opening Studio.
	pause
	exit /b 1
)
start "" build\autotest.rbxl
