@echo off
cd /d "%~dp0..\..\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\run-quality12b-revalidation.ps1" -Stage All -Execute
echo.
echo Finished or stopped. See reports\qa\quality12b_revalidation_20261005\runs\ for status.json.
pause
