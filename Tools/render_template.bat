@echo off
:: ============================================================
::  render_CHARNAME.bat  —  Auto-generated sprite renderer
::  Double-click this to render all animations for CHARNAME.
::
::  If Blender is not at the path below, update BLENDER to
::  match your installation.
:: ============================================================

:: ► UPDATE THIS if Blender is installed somewhere else
set BLENDER="C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"

:: ► UPDATE THIS to your miniSWG Tools folder
set SCRIPT=C:\Users\ryang\OneDrive\Documents\miniSWG\Tools\render_launcher.py

:: ► UPDATE THIS to your character's root folder
set CHAR=C:\Users\ryang\OneDrive\Documents\miniSWG\Characters\NEWFOUNDMETHOD\CHARNAME

:: ► UPDATE mode to "meshy" if this is a Meshy AI character
set MODE=mixamo

:: ── Animations to render ─────────────────────────────────
:: Add or remove lines below for each animation you have.
:: --start and --end are optional (auto-detected from timeline).

echo ============================================================
echo  Rendering CHARNAME sprites
echo ============================================================
echo.

echo [1/3] RUN
%BLENDER% --background --python "%SCRIPT%" -- ^
    --fbx "%CHAR%\fbx\fbxrun" ^
    --output "%CHAR%\run" ^
    --anim run --mode %MODE%
if errorlevel 1 goto :error
echo.

echo [2/3] IDLE
%BLENDER% --background --python "%SCRIPT%" -- ^
    --fbx "%CHAR%\fbx\fbxidle" ^
    --output "%CHAR%\idle" ^
    --anim idle --mode %MODE%
if errorlevel 1 goto :error
echo.

echo [3/3] ATTACK
%BLENDER% --background --python "%SCRIPT%" -- ^
    --fbx "%CHAR%\fbx\fbxattack" ^
    --output "%CHAR%\attack" ^
    --anim attack --mode %MODE%
if errorlevel 1 goto :error
echo.

echo ============================================================
echo  ALL DONE!  Sprites saved to:
echo  %CHAR%
echo ============================================================
pause
exit /b 0

:error
echo.
echo  ERROR: Blender returned an error code. Check output above.
pause
exit /b 1
