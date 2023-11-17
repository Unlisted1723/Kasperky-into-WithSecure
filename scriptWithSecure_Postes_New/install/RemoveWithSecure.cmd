@REM
REM@echo off
SETLOCAL EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
IF EXIST "%repTravail%removeWithsecure.txt (SET "FirstExecutionRemove=") ELSE (SET "FirstExecutionRemove=OK")
Echo "Debut du script removeWithsecure.cmd" >> %repTravail%removeWithsecure.txt
REM Detection SERVER ou PC standard
@For /F Tokens^=6Delims^=^" %%A In ('WMIC OS Get Caption/Format:MOF')Do (Set "OperatingSystem=%%A")
@For /F "Tokens=3 Delims= " %%A In ("!OperatingSystem!")Do (
	IF "%%A" EQU "Server" (
		REM OS VERSION Windows Server
		Set "OperatingSystemType=SERVER"
		SET "WithSecureInstaller=ElementsAgentOfflineInstaller_server_patched.msi"
	) else (
		REM OS VERSION Windows Standard
		SET "OperatingSystemType=STANDARD"
		SET "WithSecureInstaller=ElementsAgentOfflineInstaller_standard_patched.msi"
	)
)
REM =====================================================
REM TEST installation WithSecure OK or failed
REM =====================================================
if EXIST "C:\Program Files (x86)\F-Secure\PSB\ui\wsmain.exe" (
	Echo "C:\Program Files (x86)\F-Secure\PSB\ui\wsmain.exe existe" >> %repTravail%removeWithsecure.txt
	CALL :SUB_CheckWithSecureStarted
)
if "%WithsecureStarted%" EQU "1" (
	Echo WithSecure fonctionne : Verification du nettoyage de Kaspersky >> %repTravail%removeWithsecure.txt
	GOTO Fin
) else (
	Echo WithSecure Failed: Remove in progress... >> %repTravail%removeWithsecure.txt
)
REM En cas d echec de l installation de WithSecure reinstallation de KLnagent et suppression de WithSecure
echo ECHEC d une installation precedente de WithSecure >> %repTravail%removeWithsecure.txt
REM Scan Registry Uninstall
Set Uninstall_Name="WithSecure™ Elements Agent"
Set DetectedRegistryKeys=
SET NB_key=
SET x=0
echo Recherche des cles de registre DisplayName dans uninstall >> %repTravail%removeWithsecure.txt
for %%a in ("" "\Wow6432Node") do (
	SET "KEY=HKEY_LOCAL_MACHINE\SOFTWARE%%~a\Microsoft\Windows\CurrentVersion\Uninstall"
	for /f "tokens=1,2,*" %%k in ('Reg Query !KEY! /S /D /F %Uninstall_Name%') do (
		SET VAR_KEY_KES=%%k
		if "!VAR_KEY_KES:~0,18%!" EQU "HKEY_LOCAL_MACHINE" (
			SET Chemin=!VAR_KEY_KES!
			set /a x+=1
			If defined DetectedRegistryKeys (
				SET DetectedRegistryKeys=!DetectedRegistryKeys!,!Chemin!
				SET "CleMultiple_OK=True"
			) else (SET DetectedRegistryKeys=!Chemin!)
			echo Cle trouvee: "!Chemin!" >> %repTravail%removeWithsecure.txt)
		)
	)
)
Rem Nombre de cles detectes
If defined DetectedRegistryKeys (
	SET NB_key=!x!
	echo Nombre de cle detectee : !NB_key! >> %repTravail%removeWithsecure.txt
) else (
	echo KES absent du registre uninstall >> %repTravail%removeWithsecure.txt
	goto FIN
)
REM =====================================================================================================
REM Recuperation de la commande de desinstallation UninstallString
REM version KES differente de KES running
if !x! EQU 0 (GOTO Remove_Files)
SET a=0
echo "desinstallation de WithSecure" >> %repTravail%removeWithsecure.txt
for /F "delims=," %%k in (!DetectedRegistryKeys!) do (
		SET valeur=%%k
		if /I "!valeur:~1,18!" EQU "HKEY_LOCAL_MACHINE" (
			SET CleAtraiter=!valeur!
			call :SUB_Get_UninstallStringKey !CleAtraiter!
			IF defined UninstallStringCMD (
				set /a a+=1
				SET "UninstallCMD[!a!]="!uninstallStringCMD!""
				echo !a! - !uninstallStringCMD! >> %repTravail%removeWithsecure.txt
			)
		)
)
Rem Execution des commandes de desinstallation detectees dans les registres uninstall
for /l %%x in (1, 1, !a!) do (
	SET "ExecuteCMD=UninstallCMD[%%x]"
	Echo Commande: %ExecuteCMD%
	If defined ExecuteCMD (
		Call %ExecuteCMD%
		if errorlevel 1 Echo Echec de la commande %ExecuteCMD%
	)
)

Rem Withsecure Remover
%repTravail%WsUninstallationTool.exe -s -p oneclient
%repTravail%WsUninstallationTool.exe -s -p freedome
%repTravail%WsUninstallationTool.exe -s -p key
%repTravail%WsUninstallationTool.exe -s -p keydata
%repTravail%WsUninstallationTool.exe -s -p mdr
%repTravail%WsUninstallationTool.exe -s -p ElementsConnector
%repTravail%WsUninstallationTool.exe -s -p elements_connector_db
%repTravail%WsUninstallationTool.exe -s -p rdssensor
%repTravail%WsUninstallationTool.exe -s -p ultralight_av
%repTravail%WsUninstallationTool.exe -s -p quarantine
%repTravail%WsUninstallationTool.exe -s -p ess_quarantine
%repTravail%WsUninstallationTool.exe -s -p logs

:Remove_Registry
Rem Nettoyage des cles de registre de services
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsatp" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FsDepends" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsdevcon" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\F-Secure Gatekeeper" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fselms" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fshoster" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsnethoster" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsnif2" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsulhoster" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsulnethoster" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsulorsp" /f
%repTravail%psexec.exe -s -d reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\fsulprothoster" /f

:Remove_Files
Rem Nettoyage des fichiers restant
if exist "C:\ProgramData\F-Secure" (
	echo Suppression de WithSecure dans ProgramDATA >> %repTravail%removeWithsecure.txt
	del /F /S /Q "C:\ProgramData\F-Secure\"
	rd /S /Q "C:\ProgramData\F-Secure\"
	IF ERRORLEVEL 1 Echo Echec de la suppression de ProgramDATA >> %repTravail%removeWithsecure.txt
)
If exist "C:\Program Files (x86)\F-Secure" (
	del /F /S /Q "C:\Program Files (x86)\F-Secure\"
	rd /S /Q "C:\Program Files (x86)\F-Secure\"
	IF ERRORLEVEL 1 Echo Echec de la suppression de ProgramFilex86 >> %repTravail%removeWithsecure.txt
)
Goto REBOOT

REM =====================================================================================================
REM Les fonctions
REM =====================================================================================================
REM Check withsecure Started
:SUB_CheckWithSecureStarted
set /a ComptWaitStartAgent=0
:Boucle_WithsecureStarted
Call :SUB_Check_process_Started fshoster32.exe
if "%Check_process_Started%" EQU "0" (
	SET WithsecureStarted=0
	set /a ComptWaitStartAgent+=1
	TIMEOUT /T 5
	if %ComptWaitStartAgent% NEQ 6 (GOTO Boucle_WithsecureStarted)
) else (SET WithsecureStarted=1)
EXIT /B 0

REM =====================================================
REM Recherche pour chaque clé multiple de Kaspersky sa command UninstallString
:SUB_Get_UninstallStringKey
if /I "%~1"=="" EXIT /B 0
SET CleAtraiter=%~1
SET UninstallStringCMD=
SET UninstallString_Value=
SET First_Char_UninstallString_Value=
SET Value_Query_Uninstall=
for /f "delims=" %%r in ('Reg Query "!CleAtraiter!" /v UninstallString^|findstr "UninstallString"') do (SET "Value_Query_Uninstall=%%r")
if /I "!Value_Query_Uninstall!" NEQ "" (
	REM suppression des 33 premiers caracteres de la ligne
	SET "UninstallString_Value=!Value_Query_Uninstall:~33!"
	REM récupération des 11 premiers caracteres
	SET "First_Char_UninstallString_Value=!UninstallString_Value:~0,11!"
	REM convertir en majuscule pour le test
	Call :SUB_Capital_Letter "!First_Char_UninstallString_Value!"
	if /I "!First_Char_UninstallString_Value!" EQU "MSIEXEC.EXE" (SET "UninstallStringCMD=!UninstallString_Value!")
) else (
	SET UninstallStringCMD=
)
EXIT /B 0

REM =====================================================
REM Check User logged
:SUB_DETECTuserLogged
echo "verfication utilisateur present" >> %repTravail%removeWithsecure.txt
tasklist /FI "imagename eq explorer.exe" | findstr PID > NUL 2>&1
if "%ERRORLEVEL%" EQU "0" (SET "Userlogged=OK") else (
	echo "Process Explorer absent: Pas d utilisateur present donc on continue ..." >> %repTravail%removeWithsecure.txt
	SET Userlogged=
)
EXIT /B 0
REM =====================================================
REM Check process started
:SUB_Check_process_Started
if /I "%~1"=="" EXIT /B 0
SET "ProcessName=%~1"
SET "Check_process_Started=0"
tasklist /FI "imagename eq %ProcessName%" | findstr PID > NUL 2>&1
if "%ERRORLEVEL%" EQU "0" (
	SET "Check_process_Started=1"
	Echo "Process %ProcessName% detecte [%ERRORLEVEL%]" >> %repTravail%removeWithsecure.txt
) else (
	SET "Check_process_Started=0"
	Echo "Process %ProcessName% non detecte [%ERRORLEVEL%]" >> %repTravail%removeWithsecure.txt
)
EXIT /B 0
REM =====================================================================================================
REM Fin des fonctions
REM =====================================================================================================
:REBOOT
echo verification si le reboot du poste est possible. >> %repTravail%removeWithsecure.txt
IF "%OperatingSystemType%" EQU "STANDARD" (
	CALL :SUB_DETECTuserLogged
	if defined Userlogged (
		echo "Process Explorer detecte: Utilisateur present donc REBOOT annule !" >> %repTravail%removeWithsecure.txt
		schtasks /create /TN "utilisateur" /XML "%repTravail%UtilisateurpresentV2.xml"
		schtasks /run /tn utilisateur
		schtasks /delete /tn utilisateur /f
		GOTO FIN
	)
)
IF "%FirstExecutionRemove%" EQU "OK" (
	echo "Aucun utilisateur detecte donc REBOOT du poste..." >> %repTravail%removeWithsecure.txt
	msg * /w "Redemarrage de votre poste dans 10 secondes ..."
	shutdown /r /t 10 /f /c "Remove WithSecure"
)

:fin
Echo Fin du script RemoveWithSecure.cmd >> %repTravail%removeWithsecure.txt