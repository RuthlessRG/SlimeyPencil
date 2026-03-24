@echo off
cd /d "C:\Users\ryang\OneDrive\Documents\miniSWG"

:: Get current date/time for commit message
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set TIMESTAMP=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2% %datetime:~8,2%:%datetime:~10,2%

:: Stage all changes
git add -A

:: Check if there are changes to commit
git diff --cached --quiet
if %errorlevel% neq 0 (
    git commit -m "Daily auto-backup: %TIMESTAMP%"
    git push origin main
    echo [%TIMESTAMP%] Backup pushed successfully >> "%~dp0backup_log.txt"
) else (
    echo [%TIMESTAMP%] No changes to backup >> "%~dp0backup_log.txt"
)
