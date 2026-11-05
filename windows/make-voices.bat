@echo off
rem Makes the female and male voice clips with Google Cloud and sends them to
rem GitHub for the app. Run it from the project folder, for example
rem D:\LanguageLibrary\windows\make-voices.bat. The first run sets things up;
rem after that it only makes clips for words that don't have one yet.
setlocal
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1
cd /d "%~dp0.."

rem ---- conda environment
call "%~dp0find-conda.cmd" || goto :end
call "%CONDA_ROOT%\Scripts\activate.bat" "%CONDA_ROOT%"
call conda env list | findstr /b /c:"languagelibrary " >nul
if errorlevel 1 (
  echo Creating the languagelibrary conda environment. This takes a few minutes, once.
  call conda env create -f tools\environment.yml
  if errorlevel 1 goto :end
)
call conda activate languagelibrary
if errorlevel 1 goto :end

rem ---- Google Cloud sign-in
where gcloud >nul 2>&1
if errorlevel 1 (
  echo The Google Cloud CLI is not installed. Install it from the page that opens,
  echo then close this window and run this again.
  start "" https://cloud.google.com/sdk/docs/install#windows
  goto :end
)
call gcloud auth application-default print-access-token >nul 2>&1
if errorlevel 1 (
  echo A browser will open. Sign in with the Google account that has your Cloud project.
  call gcloud auth application-default login
  if errorlevel 1 goto :end
)
set PROJECT=
for /f "usebackq delims=" %%P in (`gcloud config get-value project 2^>nul`) do set "PROJECT=%%P"
if not defined PROJECT (
  set /p PROJECT=Type your Google Cloud project ID and press Enter: 
)
if not defined PROJECT goto :end
call gcloud config set project %PROJECT% >nul 2>&1
call gcloud auth application-default set-quota-project %PROJECT% >nul 2>&1

rem ---- pick voices (first time only; they are kept in the audio manifest)
set FEMALE=
set MALE=
for /f "usebackq tokens=1,2" %%A in (`python -m tools.voices_status --voices`) do (
  set "FEMALE=%%A"
  set "MALE=%%B"
)
if defined FEMALE goto :generate
echo.
echo First, samples of every Mandarin voice. A page opens when they are ready:
echo listen, then type the names of the female and male voices you like.
python -m tools.generate_audio --samples
if errorlevel 1 goto :end
start "" "tools\audio_samples\index.html"
set /p FEMALE=Female voice name (for example cmn-CN-Chirp3-HD-Aoede): 
set /p MALE=Male voice name: 
if not defined FEMALE goto :end
if not defined MALE goto :end

:generate
echo.
echo Making clips with %FEMALE% and %MALE%. Words that already have clips are skipped.
python -m tools.generate_audio --female %FEMALE% --male %MALE%
if errorlevel 1 goto :end
start "" "tools\audio_report.md"

rem ---- send them to GitHub on their own branch, for review like any other change
git add app/assets/audio tools/audio_report.md
git diff --cached --quiet
if not errorlevel 1 (
  echo No new clips to send.
  goto :end
)
for /f "usebackq delims=" %%T in (`python -c "import datetime;print(datetime.datetime.now().strftime('%%Y%%m%%d-%%H%%M'))"`) do set "STAMP=%%T"
set BRANCH=voices-%STAMP%
git checkout -b %BRANCH%
rem A neutral author, so no personal names end up in the repo.
git -c user.name=languagelibrary -c user.email=11561549+Nichevo@users.noreply.github.com commit -m "Add recorded voices"
if errorlevel 1 goto :end
git push -u origin %BRANCH%
if errorlevel 1 goto :end
git checkout main
echo.
echo Sent. A page opens to make the pull request; merge it and the next app build has the voices.
start "" "https://github.com/Nichevo/languagelibrary/compare/main...%BRANCH%?expand=1"

:end
echo.
pause
