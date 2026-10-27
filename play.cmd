@echo off
rem One click: pull latest code from GitHub, build the race place, open it in Studio.
rem Usage: double-click play.cmd, or: play.cmd branch-name
cd /d "%~dp0"

set BRANCH=%1
if "%BRANCH%"=="" set BRANCH=claude/project-thread-bryscd

git fetch origin
git checkout %BRANCH% || git checkout -b %BRANCH% origin/%BRANCH%
git pull origin %BRANCH%

if not exist build mkdir build
rojo build race.project.json -o build\race.rbxl
if errorlevel 1 (
	echo Build failed, not opening Studio.
	pause
	exit /b 1
)
start "" build\race.rbxl
