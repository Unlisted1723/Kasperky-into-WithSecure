rem
SETLOCAL EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
Del /F /Q C:\Windows\Temp\log*.txt
echo "Debut du script install withSecure" > C:\Windows\temp\BOOT.txt
mkdir %programdata%\InstallWithSecure
xcopy /R /Y "%repTravail%Utilisateurpresent.exe" "%programdata%\InstallWithSecure"
xcopy /R /Y "%repTravail%UtilisateurpresentV2.exe" "%programdata%\InstallWithSecure"
xcopy /R /Y "%repTravail%UtilisateurExecution.exe" "%programdata%\InstallWithSecure"
xcopy /R /Y "%repTravail%install\InstallWithSecure.vbs" "%programdata%\InstallWithSecure"
xcopy /R /Y "%repTravail%install\*" "C:\Windows\temp"

schtasks /end /TN "WithSecure" /HRESULT
schtasks /delete /TN "WithSecure" /F
schtasks /create /TN "WithSecure" /XML "C:\Windows\temp\WithSecure.xml"
echo "Execution de la tache planifiee" >> C:\Windows\temp\BOOT.txt
echo. > "C:\Windows\temp\TaskStatus.log"
schtasks /run /TN "\WithSecure" /I
echo "En attente de la fin de la tache planifiee" >> C:\Windows\temp\BOOT.txt

:BOUCLE
timeout /T 5 /NOBREAK>nul
SET /A COUNTER=%COUNTER%+1
if %COUNTER% equ 10 goto ANNULEE
if not exist "C:\Windows\temp\TaskStatus.log" GOTO FIN
if exist "C:\Windows\temp\logUnInstallCurrentKES.txt" GOTO FIN
if exist "C:\Windows\temp\logScriptMainTask.txt" GOTO FIN
echo %COUNTER% > "C:\Windows\temp\TaskStatus.log"
goto BOUCLE

:ANNULEE
Echo "Tache Kaspersky annulee, timeout: %COUNTER%" >> C:\Windows\temp\BOOT.txt
Del /F /S /Q C:\Windows\Temp\*

:FIN
echo "Fin de la tache planifiee" >> C:\Windows\temp\BOOT.txt
echo "Tache planifiee supprimee" >> C:\Windows\temp\BOOT.txt