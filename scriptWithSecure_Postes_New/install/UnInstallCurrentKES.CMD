@REM
REM@echo off
SETLOCAL ENABLEEXTENSIONS EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
IF EXIST "%repTravail%logUnInstallCurrentKES.txt (SET "FirstExecutionUnInstallKES=") ELSE (SET "FirstExecutionUnInstallKES=OK")

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
REM =====================================================================================================
REM Debut
REM =====================================================================================================
echo. >> %repTravail%logUnInstallCurrentKES.txt
echo DEBUT du script installWithSecure.cmd sur %OperatingSystem% : %OperatingSystemType%
echo DEBUT du script installWithSecure.cmd sur %OperatingSystem% : %OperatingSystemType% >> %repTravail%logUnInstallCurrentKES.txt
Echo %DATE% %TIME% >> %repTravail%logUnInstallCurrentKES.txt

REM =====================================================
REM Uninstall current KES
REM =====================================================
REM Recup des parametres de desinstallation de Kaspersky
if exist "%repTravail%cleanupKESAfterInstallWithSecureEndded.param" (
	SET ComptParam=0
	for /F "delims=" %%v in (%repTravail%cleanupKESAfterInstallWithSecureEndded.param) DO (
		SET /A ComptParam+=1
		SET "PARAM[!ComptParam!]=%%v"
	)
	Echo Liste des parametres: >> %repTravail%logUnInstallCurrentKES.txt
	for /l %%b in (1, 1, !ComptParam!) do (Echo "PARAM[%%b]: !PARAM[%%b]!" >> %repTravail%logUnInstallCurrentKES.txt)
	SET KES_Started_Uninstall_CMD=!PARAM[1]:"=!
	SET KES_Process_Started_Name=!PARAM[2]:"=!
	SET KES_Process_Started_Path=!PARAM[3]:"=!
	Echo. >> %repTravail%logUnInstallCurrentKES.txt
	Echo "KES_Started_Uninstall_CMD=!PARAM[1]!" >> %repTravail%logUnInstallCurrentKES.txt
	Echo "KES_Process_Started_Name=!PARAM[2]!" >> %repTravail%logUnInstallCurrentKES.txt
	Echo "KES_Process_Started_Path=!PARAM[3]!" >> %repTravail%logUnInstallCurrentKES.txt
) else (
	echo Le fichier cleanupKESAfterInstallWithSecureEndded.param est absent >> %repTravail%logUnInstallCurrentKES.txt
	Goto FindKSNagentRegistry
)
REM supprime les guillemets
SET KES_Started_Uninstall_CMD=%KES_Started_Uninstall_CMD:"=%
echo Desinstallation de %KES_Process_Started_Name% >> %repTravail%logUnInstallCurrentKES.txt
echo Execution de : %KES_Started_Uninstall_CMD% >> %repTravail%logUnInstallCurrentKES.txt
REM remplace Quiet par Passive dans la commande de desinstallation
%KES_Started_Uninstall_CMD%
If %errorlevel% EQU 0 (Echo Desinstallation de KES reussie: %errorlevel%)

REM =====================================================
REM Uninstall current KSN Agent
REM =====================================================
REM Recherche des clés de registre uninstall concernant KSNagent
:FindKSNagentRegistry
Set KES_Display_Name="Agent d'administration de Kaspersky Security Center"
Set DetectedRegistryKeys=
SET NB_KES_key=
SET x=0
echo Recherche de la cle de registre uninstall pour l agent Kaspersky >> %repTravail%logUnInstallCurrentKES.txt
for %%a in ("" "\Wow6432Node") do (
	SET "KEY=HKEY_LOCAL_MACHINE\SOFTWARE%%~a\Microsoft\Windows\CurrentVersion\Uninstall"
	for /F %%e in ('Reg Query !KEY! /S /D /F %KES_Display_Name%^|findstr HKEY_LOCAL_MACHINE') do (
		SET /A x+=1
		SET "QueryResult[!x!]=%%e"
	)
)
for /l %%a in (1, 1, !x!) do (Echo %%a - Cle detectee: !QueryResult[%%a]! >> %repTravail%logUnInstallCurrentKES.txt)
echo Verif si la cle de registre est correct ...>> %repTravail%logUnInstallCurrentKES.txt
for /l %%a in (1, 1, !x!) do (
	Set "KeyNameToCheck=!QueryResult[%%a]!"
	Call :SUB_Reg_Key_Name !KeyNameToCheck!
	SET "DebutKeyName=!KeyName:~0,11!"
	REM Echo Debut KeyName: !DebutKeyName! >> %repTravail%logUnInstallCurrentKES.txt
	if "!DebutKeyName!" NEQ "InstallWIX_" (
		REM if defined DetectedRegistryKeys (SET "DetectedRegistryKeys=!DetectedRegistryKeys!,!QueryResult[%%a]!") else (SET "DetectedRegistryKeys=!QueryResult[%%a]!")
		SET "DetectedRegistryKeys=!QueryResult[%%a]!"
	)
)
If defined DetectedRegistryKeys (Echo OK >> %repTravail%logUnInstallCurrentKES.txt) else (GOTO Fin)

REM Recherche de la clé de registre InstallLocation (path) pour chaque clé de KSNagent
SET uninstallString=
SET KESkeyToUninstall=
echo Verif de la valeur InstallLocation de la cle de registre >> %repTravail%logUnInstallCurrentKES.txt
for /f "delims=" %%k in ('Reg Query "!DetectedRegistryKeys!" /v InstallLocation^|findstr "InstallLocation"') do (
		SET Reg_Value_InstallLocation=%%k
		IF defined Reg_Value_InstallLocation (SET InstallLocationString_Value=!Reg_Value_InstallLocation:~33!)
)
call :SUB_Get_UninstallStringKey !DetectedRegistryKeys!

Rem Desinstallation de KSNagent
Echo. >> %repTravail%logUnInstallCurrentKES.txt
If defined DetectedRegistryKeys Echo Cle trouvee: "!DetectedRegistryKeys!" >> %repTravail%logUnInstallCurrentKES.txt
If defined InstallLocationString_Value Echo Chemin de KSNagent: "%InstallLocationString_Value%" >> %repTravail%logUnInstallCurrentKES.txt
If defined UninstallStringCMD Echo Commande de desinstallation: %UninstallStringCMD% >> %repTravail%logUnInstallCurrentKES.txt
%UninstallStringCMD% /quiet
If %errorlevel% EQU 0 (
	Echo Desinstallation de KSNagent reussie: %errorlevel% >> %repTravail%logUnInstallCurrentKES.txt
	GOTO Reboot
) else (
	Echo Echec de la desinstallation de KSNagent  >> %repTravail%logUnInstallCurrentKES.txt
)
Goto fin

REM =====================================================================================================
REM Functions
REM =====================================================================================================
REM Function Convertion en majuscule
:SUB_Capital_Letter
if /I "%~1"=="" EXIT /B 0
if /I "%~2"=="" EXIT /B 0
for /F "delims=" %%a in ("%~1") do (
   set "line=%%a"
   for %%b in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
      set "line=!line:%%b=%%b!"
   )
)
SET "%~2=!line!"
EXIT /B 0
REM =====================================================
REM Recherche pour chaque de la command UninstallString pour KSNagent
:SUB_Get_UninstallStringKey
if /I "%~1"=="" EXIT /B 0
SET CleAtraiter=%~1
SET UninstallString_Value=
SET First_Char_UninstallString_Value=
SET Value_Query_Uninstall=
SET "UninstallStringCMD=empty"
for /f "delims=" %%r in ('Reg Query "!CleAtraiter!" /v UninstallString^|findstr "UninstallString"') do (SET "Result_Query_Uninstall=%%r")
Call :SUB_Capital_Letter "!Result_Query_Uninstall!" Result_Query_Uninstall
REM Echo Capital letter: %Result_Query_Uninstall% >> %repTravail%logUnInstallCurrentKES.txt
if /I "%Result_Query_Uninstall%" NEQ "" (
	for /f "tokens=3 delims= " %%r in ("%Result_Query_Uninstall%") do (SET "Value_Query_Uninstall=%%r")
	REM Echo TEST Value_Query_Uninstall: !Value_Query_Uninstall! >> %repTravail%logUnInstallCurrentKES.txt
)
if /I "!Value_Query_Uninstall!" EQU "MSIEXEC.EXE" (
	REM Echo Result_Query_Uninstall: !Result_Query_Uninstall!  >> %repTravail%logUnInstallCurrentKES.txt
	for /f "tokens=3,* delims= " %%a in ("!Result_Query_Uninstall!") do (SET "UninstallStringCMD=%%a %%b")
)
REM Echo Valeurs a traiter: !UninstallStringCMD! >> %repTravail%logUnInstallCurrentKES.txt
EXIT /B 0
REM =====================================================
REM Extraction du nom d une cle de registre a partir du chemin complet
:SUB_Reg_Key_Name
if /I "%~1"=="" EXIT /B 0
SET KeyNameToCheck=%~1
:loop
for /f "tokens=1,* delims=\" %%k in ("!KeyNameToCheck!") Do (
	SET Keyname=%%k
	SET NextKeyname=%%l
	if "!NextKeyname!" NEQ "" (
		SET "KeyNameToCheck=!NextKeyname!"
		goto loop
	)
)
REM Echo KeyName: !KeyName! >> %repTravail%logUnInstallCurrentKES.txt
EXIT /B 0

REM =====================================================================================================
REM Fin des fonctions
REM =====================================================================================================
:Reboot
IF "%FirstExecutionUnInstallKES%" EQU "OK" (
	echo verification si le reboot du poste est possible. >> %repTravail%removeWithsecure.txt
	IF "%OperatingSystemType%" EQU "STANDARD" (
		echo "REBOOT du poste apres desinstallation ..." >> %repTravail%logScriptCall.txt
		msg * /w "Redemarrage de votre poste dans 10 secondes ..."
		shutdown /r /t 10 /f /c "Desinstallation de Kaspersky avant installation de WithSecure"
	)
)

:FIN
echo Fin du script UnInstallKES.cmd >> %repTravail%logUnInstallCurrentKES.txt
