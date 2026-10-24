@echo off
rem Один клик: обновить код с GitHub, собрать гоночный плейс и открыть его в Studio.
rem Запуск: двойной щелчок по play.cmd. Другая ветка: play.cmd имя-ветки
cd /d "%~dp0"

set BRANCH=%1
if "%BRANCH%"=="" set BRANCH=claude/project-thread-bryscd

git fetch origin
git checkout %BRANCH% || git checkout -b %BRANCH% origin/%BRANCH%
git pull origin %BRANCH%

if not exist build mkdir build
rojo build race.project.json -o build\race.rbxl
if errorlevel 1 (
	echo Сборка не удалась, Studio не открываю.
	pause
	exit /b 1
)
start "" build\race.rbxl
