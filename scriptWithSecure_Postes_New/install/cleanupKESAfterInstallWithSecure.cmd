@REM
@echo off
SETLOCAL EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
IF EXIST "%repTravail%InstallWithSecureEndded.log" (del /F /S /Q "%repTravail%InstallWithSecureEndded.log")
echo. >> %repTravail%logScriptInstallWithSecure.txt
echo DEBUT du script cleanupKESAfterInstallWithSecure.cmd >> %repTravail%logScriptInstallWithSecure.txt

REM Recup des parametres
if exist "%repTravail%cleanupKESAfterInstallWithSecureEndded.param" (
	SET ComptParam=0
	for /F "delims=" %%v in (%repTravail%cleanupKESAfterInstallWithSecureEndded.param) DO (
		SET /A ComptParam+=1
		SET "PARAM[!ComptParam!]=%%v"
	)
	Echo Liste des parametres: >> %repTravail%logScriptInstallWithSecure.txt
	for /l %%b in (1, 1, !ComptParam!) do (Echo "PARAM[%%b]: !PARAM[%%b]!" >> %repTravail%logScriptInstallWithSecure.txt)
	SET KES_Started_Uninstall_CMD=!PARAM[1]:"=!
	SET KES_Process_Started_Name=!PARAM[2]:"=!
	SET KES_Process_Started_Path=!PARAM[3]:"=!
	Echo. >> %repTravail%logScriptInstallWithSecure.txt
	Echo "KES_Started_Uninstall_CMD=!PARAM[1]!" >> %repTravail%logScriptInstallWithSecure.txt
	Echo "KES_Process_Started_Name=!PARAM[2]!" >> %repTravail%logScriptInstallWithSecure.txt
	Echo "KES_Process_Started_Path=!PARAM[3]!" >> %repTravail%logScriptInstallWithSecure.txt
) else (
	echo Le fichier cleanupKESAfterInstallWithSecureEndded.param est absent >> %repTravail%logScriptInstallWithSecure.txt
	Goto Fin
)
REM Verification de la désinstallation de la version précédente de KES apres l installation de Withsecure
set /a ComptWaitStopAVP=0
:Boucle_KESstarted
Call :SUB_Check_process_Started avp.exe
if %Check_process_Started% EQU 1 (
	SET KESInstalledAndStarted=1
	GOTO RemoveKESstarted
)
if %Check_process_Started% EQU 0 (
	REM AVP not started
	SET KESInstalledAndStarted=0
)
REM Nettoyage de la version précédente de KES qui aurait du etre supprimee pendant l installation de Withsecure
:RemoveKESstarted
if %KESInstalledAndStarted% EQU 1 (
	REM Desinstallation propre de KES
	REM supprime les guillemets
	SET KES_Started_Uninstall_CMD=%KES_Started_Uninstall_CMD:"=%
	echo Desinstallation de %KES_Process_Started_Name% >> %repTravail%logScriptInstallWithSecure.txt
	echo Execution de : %KES_Started_Uninstall_CMD% >> %repTravail%logScriptInstallWithSecure.txt
	REM remplace Quiet par Passive dans la commande de desinstallation
	%KES_Started_Uninstall_CMD%
	Echo Code d erreur %ERRORLEVEL% apres execution de "%KES_Started_Uninstall_CMD%"
)
set /a ComptWaitStopAVP=0
:Boucle_WaitKESstop
Call :SUB_Check_process_Started avp.exe
if %Check_process_Started% EQU 1 (
	REM AVP started waiting it will stop after 30s
	SET KESInstalledAndStarted=1
	set /a ComptWaitStopAVP+=1
	TIMEOUT /T 5
	if %ComptWaitStopAVP% NEQ 6 (GOTO Boucle_WaitKESstop)
)
IF %ComptWaitStopAVP% EQU 6 Echo Uninstall KES Failed ComptWaitStopAVP: "%ComptWaitStopAVP%" >> %repTravail%logScriptInstallWithSecure.txt
IF %ComptWaitStopAVP% LSS 6 Echo La desinstallation de KES a reussi >> %repTravail%logScriptInstallWithSecure.txt

:DeleteAllKES
if exist "%KES_Process_Started_Path%" (
	REM Desinstallation forcee de KES
	echo Suppression du repertoire "%KES_Process_Started_Path%" >> %repTravail%logScriptInstallWithSecure.txt
	REM net stop %KES_Process_Started_Name%
	REM sc config "%KES_Process_Started_Name%" start=disabled
	echo y | cacls "!KES_Process_Started_Path!" /e /t /c /g "everyone":F
	rmdir /q /s "!KES_Process_Started_Path!"
)
Goto FIN

REM =====================================================================================================
REM Functions
REM =====================================================
REM Check process started
:SUB_Check_process_Started
if /I "%~1"=="" EXIT /B 0
SET ProcessName=%~1
SET Check_process_Started=0
tasklist /FI "imagename eq %ProcessName%" | findstr PID > NUL 2>&1
if %errorlevel% EQU 0 (SET Check_process_Started=1) else (SET Check_process_Started=0)
EXIT /B 0

:FIN
Echo "FIN du script cleanupKESAfterInstallWithSecure.cmd" >> %repTravail%logScriptInstallWithSecure.txt