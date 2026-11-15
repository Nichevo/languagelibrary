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
rem gcloud is installed into the conda environment (google-cloud-sdk from conda-forge).
rem It is not in tools\environment.yml so that the rest still sets up if conda-forge lacks it.
where gcloud >nul 2>&1
if errorlevel 1 (
  echo Adding the Google Cloud tools to the conda environment. This takes a few minutes, once.
  call conda install -y -n languagelibrary -c conda-forge google-cloud-sdk
  call conda deactivate
  call conda activate languagelibrary
)
where gcloud >nul 2>&1
if errorlevel 1 (
  echo The Google Cloud tools could not be found. Install them from the page that opens,
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
echo.
echo Checking again, a few different ways, any clip speech recognition couldn't confirm.
echo Clips that still can't be confirmed are left out of the app, which uses the phone's voice for them.
python -m tools.generate_audio --recheck --female %FEMALE% --male %MALE%
if errorlevel 1 goto :end
echo.
echo Making again any clip listed in tools\sources\remake_clips.tsv as sounding wrong.
python -m tools.generate_audio --remake --female %FEMALE% --male %MALE%
if errorlevel 1 goto :end

rem ---- the pitch line of each clip, drawn dotted on the Say it graph
echo.
echo Working out the pitch line of any new clips.
python -m tools.pitch_refs
if errorlevel 1 goto :end

rem ---- HSK 7 to 9: voiced now while there is cloud credit, kept out of the app (extra\hsk7-9)
if exist "extra\hsk7-9\library.json" (
  echo.
  echo Now the HSK 7 to 9 words. They stay out of the app until you want them.
  python -m tools.generate_audio --set hsk7-9 --female %FEMALE% --male %MALE%
  if errorlevel 1 goto :end
  python -m tools.generate_audio --set hsk7-9 --recheck --female %FEMALE% --male %MALE%
  if errorlevel 1 goto :end
)

rem ---- send them to GitHub on their own branch, for review like any other change
git add app/assets/audio tools/audio_report.md extra
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
