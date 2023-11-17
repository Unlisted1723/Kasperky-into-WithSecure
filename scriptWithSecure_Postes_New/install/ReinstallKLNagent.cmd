@REM
@echo off
SETLOCAL EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
set AppliToUninstall="Agent d'administration de Kaspersky Security Center"
SET "KlNagentInstaller=installer.exe"

echo. >> %repTravail%logScriptInstallWithSecure.txt
echo DEBUT du script ReinstallKLNagent.cmd >> %repTravail%logScriptInstallWithSecure.txt
date /T >> %repTravail%logScriptInstallWithSecure.txt
time /T >> %repTravail%logScriptInstallWithSecure.txt

REM =====================================================
rem TESTs MSI installation in progress
REM =====================================================
echo.
echo TEST autre installation en cours de package MSI >> %repTravail%logScriptInstallWithSecure.txt
echo -------
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress" 2>NUL
echo Resultat du Test d installation en cours:%errorlevel% >> %repTravail%logScriptInstallWithSecure.txt
IF %errorlevel% EQU 0 (
	echo on sort 4, Reboot en attente >> %repTravail%logScriptInstallWithSecure.txt
	msg * "Attention l installation de l antivirus WithSecure est reportee au prochain redemarrage du PC car une mise a jour prioritaire etait en attente." 
	exit -4
) else (echo Pas d autre installation en cours, on continue... >> %repTravail%logScriptInstallWithSecure.txt)
echo. >> %repTravail%logScriptInstallWithSecure.txt

REM =====================================================
rem KLNAgent fonctionne ?
REM =====================================================
:Check_KlnAgent
REM Verfication du bon fonctionnement de l agent Kaspersky pour remonter l etat de l installation
REM Au boot du system le demarrage du service de l'agent Kaspersky est différé ce qui prend environ 120 secondes
set /a ComptWaitKlnAgent=0
:Boucle_KlnAgent
Call :SUB_Check_process_Started klnagent.exe
if %Check_process_Started% EQU 0 (
	REM le processus ne fonctionne pas
	if exist "C:\Program Files (x86)\Kaspersky Lab\NetworkAgent\klnagent.exe" (SET klnAgentInstalled=0)
	set /a ComptWaitKlnAgent+=1
	TIMEOUT /T 5
	REM Boucle d'attente du processus klnagent.exe
	if %ComptWaitKlnAgent% NEQ 1 (GOTO Boucle_KlnAgent) else (GOTO FindKLagentUninstaller)
) else (GOTO FIN)

REM =====================================================
REM Remove KLNAgent
REM =====================================================
:FindKLagentUninstaller
cls
set /A nb=0
REM Recherche de la commande de desinstallation MSI de KLNagent car l'installation de WithSecure peut le rendre instable 
REM et pourrait necessiter une reinstallation
REM La desinstallation de l'agent sera effectuee via la console Kaspersky
echo. >> %repTravail%logScriptInstallWithSecure.txt
echo -------
REM Recherche des clés de registre Uninstall contenant l application
set /A nbFind=0
echo. >> %repTravail%logScriptInstallMAJCampus.txt
echo -------
for %%a in ("" "\Wow6432Node") do (
	SET KEY="HKEY_LOCAL_MACHINE\SOFTWARE%%~a\Microsoft\Windows\CurrentVersion\Uninstall"
	for /f "delims=" %%k in ('Reg Query !KEY! /S /D /F %AppliToUninstall% /E') do (
		SET valeur=%%k
		rem recup les 18 premiers caracteres pour HKEY_LOCAL_MACHINE
		SET valeur=!valeur:~0,18!
		if /I "!valeur:~0,18!" EQU "HKEY_LOCAL_MACHINE" (
			set /a nbFind += 1
			set tmp=KEY_Content[!nbFind!]
			SET "KEY_Content[!nbFind!]=%%k"
			Echo Recherche: %%k
		)
	)
)
Echo Nombre de resultat: !nbFind!
REM Verification des clés de registre trouvees
for /L %%d in (1,1,!nbFind!) do (
	SET "KEY=!KEY_Content[%%d]!"
	for /f "tokens=1,* delims=" %%k in ('Reg Query !KEY! /v DisplayName') do (
		SET valeur=%%k
		SET "valeur=!valeur:    =,!"
		for /f "tokens=3 delims=," %%g in ("!valeur!") do (
			SET "DisplayName=%%g"
			IF "!DisplayName!" EQU %AppliToUninstall% (
				CALL :SUB_Get_KeyName !KEY!
				SET FirstCharsKey_Name=!KeyName:~0,11!
				If "!FirstCharsKey_Name!" NEQ "InstallWIX_" (
					SET /A NbKey += 1
					Echo Nom de la cle: !Key!
					SET ValidKey[!NbKey!]=!Key!
				)
			)
		)
	)
)			

Echo Nombre de cle trouvee: !NbKey!
REM Recuperation UninstallString des clés de registre trouvees
for /L %%a in (1,1,!NbKey!) do (
	SET "KEY=!ValidKey[%%a]!"
	for /f "tokens=1,* delims=" %%k in ('Reg Query !KEY! /v UninstallString') do (
		SET valeur=%%k
		SET "valeur=!valeur:    =,!"
		for /f "tokens=3 delims=," %%g in ("!valeur!") do (
			SET "UninstallString=%%g"
			SET FirstCharsKey_UninstallString=!UninstallString:~0,11!
			Call :SUB_Capital_Letter "!FirstCharsKey_UninstallString!"
			if /I "!FirstCharsKey_UninstallString!" EQU "MSIEXEC.EXE" (
				SET "Command[%%a]=!UninstallString! /q"
			)
		)
	)
)
REM Recuperation InstallLocation des clés de registre trouvees
for /L %%a in (1,1,!NbKey!) do (
	SET "KEY=!ValidKey[%%a]!"
	for /f "tokens=1,* delims=" %%k in ('Reg Query !KEY! /v InstallLocation') do (
		SET "valeur=%%k"
		SET "valeur=!valeur:    =,!"
		for /f "tokens=3 delims=," %%g in ("!valeur!") do (
			SET "InstallLocation=%%g"
			SET "FirstCharsKey_InstallLocation=!InstallLocation:~0,16!"
			Call :SUB_Capital_Letter "!FirstCharsKey_InstallLocation!"
			if /I "!FirstCharsKey_InstallLocation!" EQU "C:\Program Files" (
				SET "KLNagentInstallLocation[%%a]=!InstallLocation! /q"
			)
		)
	)
)

REM Execution des commandes de desinstallation
Echo Nombre de commande de desinstallation: !NbKey!
For /L %%a in (1,1,!NbKey!) do (
	IF "!Command[%%a]!" NEQ "" (
		Echo !Command[%%a]!
		CALL !Command[%%a]!
	)
	IF %Errorlevel% EQU 0 (
		IF Exist "!KLNagentInstallLocation[%%a]!" (
			Echo Suppression du repertoire "!KLNagentInstallLocation[%%a]!" >> %repTravail%logScriptInstallWithSecure.txt
			del /F /S /Q "!KLNagentInstallLocation[%%a]!" && (echo execution DEL OK  >> %repTravail%logScriptInstallWithSecure.txt ) || (echo execution DEL NOK >> %repTravail%logScriptInstallWithSecure.txt )
			rmdir /q /s "!KLNagentInstallLocation[%%a]!" && (echo execution RMDIR OK >> %repTravail%logScriptInstallWithSecure.txt ) || (echo execution RMDIR NOK >> %repTravail%logScriptInstallWithSecure.txt )
		)
	)
)

REM =====================================================
REM reinstallation du Kaspersky network agent pour remonter l etat de l installation
REM =====================================================
Echo Reinstallation de l agent Kaspersky
Echo Reinstallation de l agent Kaspersky >> %repTravail%logScriptInstallWithSecure.txt
CALL :SUB_InstallKlnAgent
GOTO Fin

REM =====================================================================================================
REM FONCTIONS
REM =====================================================
REM Function Convertion en majuscule
:SUB_Capital_Letter
if /I "%~1"=="" EXIT /B 0
for /F "delims=" %%a in ("%~1") do (
   set "line=%%a"
   for %%b in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
      set "line=!line:%%b=%%b!"
   )
   SET "%~1=!line!"
)
EXIT /B 0

REM =====================================================
REM Install KlnAgent
:SUB_InstallKlnAgent
echo installation de l agent Kasperksy >> %repTravail%logScriptInstallWithSecure.txt
"%repTravail%%KlNagentInstaller%" /s

SET ComptWaitInstallKnlagent=0
:Boucle_InstallLknagent
Call :SUB_Check_process_Started %KlNagentInstaller%
if %Check_process_Started% EQU 1 (
	set /a ComptWaitInstallKnlagent+=1
	TIMEOUT /T 5
	if %ComptWaitInstallKnlagent% NEQ 6 (GOTO Boucle_InstallLknagent)
)
EXIT /B 0

REM =====================================================
REM Check process started
:SUB_Check_process_Started
if /I "%~1"=="" EXIT /B 0
SET ProcessName=%~1
SET Check_process_Started=0
tasklist /FI "imagename eq %ProcessName%" | findstr PID > NUL 2>&1
if %errorlevel% EQU 0 (SET Check_process_Started=1) else (SET Check_process_Started=0)
EXIT /B 0

REM =====================================================
REM GET Key Name
:SUB_Get_KeyName
if /I "%~1"=="" EXIT /B 0
SET List=%~1
REM SET "List=%List:\= %"
:Loop
for /f "tokens=1,* delims=\" %%m in ("%List%") do (
	SET "NextValue=%%n"
	SET /A nbList += 1
	if "!NextValue!" NEQ "" (
		SET "List=!NextValue!"
		GOTO Loop
	)
)
SET "KeyName=!List!"
EXIT /B 0

REM =====================================================================================================
REM FIN
REM =====================================================================================================
:FIN
Echo Fin du script ReinstallKLNagent
Echo Fin du script ReinstallKLNagent  >> %repTravail%logScriptInstallWithSecure.txt
