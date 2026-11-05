@rem Finds Miniconda or Anaconda and sets CONDA_ROOT. Used by the other scripts.
@rem Set CONDA_ROOT yourself before running them if yours is somewhere else.
@if defined CONDA_ROOT if exist "%CONDA_ROOT%\Scripts\activate.bat" exit /b 0
@set CONDA_ROOT=
@if defined CONDA_EXE for %%I in ("%CONDA_EXE%\..\..") do @set "CONDA_ROOT=%%~fI"
@if defined CONDA_ROOT if exist "%CONDA_ROOT%\Scripts\activate.bat" exit /b 0
@for %%D in (
  "%USERPROFILE%\miniconda3"
  "%USERPROFILE%\anaconda3"
  "D:\Users\%USERNAME%\miniconda3"
  "D:\Users\%USERNAME%\anaconda3"
  "C:\Users\%USERNAME%\miniconda3"
  "%LOCALAPPDATA%\miniconda3"
  "%ProgramData%\miniconda3"
  "%ProgramData%\anaconda3"
) do @if exist "%%~D\Scripts\activate.bat" (
  set "CONDA_ROOT=%%~D"
  exit /b 0
)
@echo Could not find Miniconda or Anaconda.
@echo Open "Anaconda Prompt" and run this script from there, or set CONDA_ROOT first.
@exit /b 1
