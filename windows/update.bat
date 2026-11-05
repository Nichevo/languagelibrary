@echo off
rem Gets the latest version of the project from GitHub and updates the
rem conda environment. Safe to run any time. Run it from the project folder
rem (for example D:\LanguageLibrary\windows\update.bat).
rem It runs from a copy in %TEMP%, because Windows misreads a .bat file that
rem changes while it is running, and the update may change this one.
if /i not "%~1"=="--from-copy" (
  copy /y "%~f0" "%TEMP%\languagelibrary-update.bat" >nul
  "%TEMP%\languagelibrary-update.bat" --from-copy "%~dp0"
  exit /b
)
setlocal
set "HERE=%~2"
chcp 65001 >nul
cd /d "%HERE%.."

where git >nul 2>&1
if errorlevel 1 (
  echo Git is not installed. Get it from https://git-scm.com/download/win and run this again.
  start "" https://git-scm.com/download/win
  goto :end
)

rem Leave any local changes alone rather than overwrite them.
git diff --quiet
if errorlevel 1 goto :changes
git diff --cached --quiet
if errorlevel 1 goto :changes

echo Getting the latest version...
git checkout main
if errorlevel 1 goto :end
git pull --ff-only origin main
if errorlevel 1 (
  echo.
  echo Could not update. If GitHub asked you to sign in, do that and run this again.
  goto :end
)

call "%HERE%find-conda.cmd" || goto :end
call "%CONDA_ROOT%\Scripts\activate.bat" "%CONDA_ROOT%"
call conda env list | findstr /b /c:"languagelibrary " >nul
if errorlevel 1 (
  echo The languagelibrary environment is not set up yet. make-voices.bat sets it up the first time.
) else (
  echo Updating the languagelibrary conda environment...
  call conda env update -n languagelibrary -f tools\environment.yml --prune
)

call conda activate languagelibrary >nul 2>&1
if errorlevel 1 goto :done
python -m tools.voices_status
if errorlevel 2 goto :done
echo.
choice /m "Some words have no recorded voice yet. Make them now"
if errorlevel 2 goto :done
call "%HERE%make-voices.bat"
goto :end

:done
echo.
echo Up to date.
goto :end

:changes
echo You have changes in this folder that are not on GitHub yet, so nothing was updated:
git status --short
echo Undo them with "git checkout -- ." (or ask Claude what to do), then run this again.

:end
echo.
pause
