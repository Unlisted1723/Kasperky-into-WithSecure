@REM
@echo off
SETLOCAL EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
if EXIST "%repTravail%cleanupKESAfterInstallWithSecureEndded.param" (del /F /S /Q "%repTravail%cleanupKESAfterInstallWithSecureEndded.param")
if EXIST "%repTravail%cleanupKESbeforeInstallWithSecureEndded.log" (del /F /S /Q "%repTravail%cleanupKESbeforeInstallWithSecureEndded.log")
SET ComptWaitLoop=0

echo. >> %repTravail%logScriptInstallWithSecure.txt
echo DEBUT du script cleanupKESbeforeInstallWithSecure.cmd >> %repTravail%logScriptInstallWithSecure.txt
date /T >> %repTravail%logScriptInstallWithSecure.txt
time /T >> %repTravail%logScriptInstallWithSecure.txt

REM =====================================================
rem TESTs MSI installation in progress
REM =====================================================
echo.
echo TEST autre installation en cours de package MSI >> %repTravail%logScriptInstallWithSecure.txt
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress" 2>NUL
IF %errorlevel% EQU 0 (
	echo on sort 4, Reboot en attente >> %repTravail%logScriptInstallWithSecure.txt
	msg * "/!\ Attention, l installation de votre nouvel antivirus a été reportee au prochain redemarrage du PC car une mise a jour prioritaire etait en attente d installation." 
	exit -4
) else (echo Pas d autre installation en cours, on continue... >> %repTravail%logScriptInstallWithSecure.txt)
echo. >> %repTravail%logScriptInstallWithSecure.txt
echo ------- >> %repTravail%logScriptInstallWithSecure.txt

REM Detect KES Started during 15s
:DetectKESinstalled
SET "ProcessName=avp.exe"
Call :SUB_Check_process_Started %ProcessName%
if %Check_process_Started% EQU 1 (
	SET ComptWaitLoop=0
	GOTO DetectKESVersionStarted
) else (
	set /a ComptWaitLoop+=1
	TIMEOUT /T 5
	if %ComptWaitLoop% NEQ 3 (GOTO DetectKESinstalled)
)
Echo "KES %ProcessName% is not running on %COMPUTERNAME%" >> %repTravail%logScriptInstallWithSecure.txt
SET "KESNOTrunning=1"
GOTO ScanRegistry

REM =====================================================
REM which KES version is Running ?
REM =====================================================
:DetectKESVersionStarted
echo Detection de la version de KES Running >> %repTravail%logScriptInstallWithSecure.txt
for /f usebackq^ delims^=^" %%i in (`wmic service where "name like 'avp.kes%%' and state = 'Running'" get pathname ^|findstr /I avp.exe`) do (set "KES_Process_Started_Path=%%i")
if defined KES_Process_Started_Path (
	for /f usebackq %%j in (`wmic service where "name like 'avp.kes%%' and state = 'Running'" get name ^|findstr /I avp.kes.`) do (set "KES_Process_Started_Name=%%j")
)
REM Extraction du Root PATH de KES en cours d execution
:DELETE_LAST_CHAR
Set "LastCharOf_KES_Process_Started_Path=%KES_Process_Started_Path:~-1%"
if "%LastCharOf_KES_Process_Started_Path%" EQU "\" (Goto EndOf_DELETE_LAST_CHAR)
if defined KES_Process_Started_Path (
	SET "KES_Process_Started_Path=%KES_Process_Started_Path:~0,-1%"
	GOTO DELETE_LAST_CHAR
)
:EndOf_DELETE_LAST_CHAR
if defined KES_Process_Started_Path (echo Racine du PATH KES: "%KES_Process_Started_Path%" >> %repTravail%logScriptInstallWithSecure.txt)
if defined KES_Process_Started_Name (echo Nom du service KES: "%KES_Process_Started_Name%" >> %repTravail%logScriptInstallWithSecure.txt)

echo Fin de la detection >> %repTravail%logScriptInstallWithSecure.txt
echo. >> %repTravail%logScriptInstallWithSecure.txt

REM =====================================================
REM Recherche des clés de registre uninstall concernant KES
REM =====================================================
:ScanRegistry
Set KES_Display_Name="Kaspersky*Endpoint"
Set DetectedRegistryKeys=
SET NB_KES_key=
SET x=0
echo Recherche des cles de registre uninstall pour Kaspersky Endpoint Security KES  >> %repTravail%logScriptInstallWithSecure.txt
for %%a in ("" "\Wow6432Node") do (
	SET "KEY=HKEY_LOCAL_MACHINE\SOFTWARE%%~a\Microsoft\Windows\CurrentVersion\Uninstall"
	for /f "tokens=1,2,*" %%k in ('Reg Query !KEY! /S /D /F %KES_Display_Name%') do (
		SET VAR_KEY_KES=%%k
		if "!VAR_KEY_KES:~0,18%!" EQU "HKEY_LOCAL_MACHINE" (
			SET Chemin=!VAR_KEY_KES!
			set /a x+=1
			If defined DetectedRegistryKeys (
				SET DetectedRegistryKeys=!DetectedRegistryKeys!,!Chemin!
				SET "CleMultiple_OK=True"
			) else (SET DetectedRegistryKeys=!Chemin!)
			echo Cle trouvee: "!Chemin!" >> %repTravail%logScriptInstallWithSecure.txt)
		)
	)
)
If defined DetectedRegistryKeys (
	SET NB_KES_key=!x!
	echo Nombre de cle detectee : !NB_KES_key! >> %repTravail%logScriptInstallWithSecure.txt
) else (
	echo KES absent du registre uninstall >> %repTravail%logScriptInstallWithSecure.txt
	SET "KESRegistryEmpty=1"
	goto FIN
)
REM =====================================================
REM Recherche de la clé de registre InstallLocation (path) pour chaque clé de KES
REM =====================================================
SET x=0
SET y=0
SET CleAtraiter=
SET uninstallString=
SET KESkeyToUninstall=
for %%a in (%DetectedRegistryKeys%) do (
	SET CleAtraiter=%%a
	for /f "delims=" %%k in ('Reg Query "!CleAtraiter!" /v InstallLocation^|findstr "InstallLocation"') do (
		SET Reg_Value_InstallLocation=%%k
		SET InstallLocationString_Value=!Reg_Value_InstallLocation:~33!
		if /I !KES_Process_Started_Path! NEQ !InstallLocationString_Value! (
			REM comptage des cles KES dont la version est differente de KES_Process_Started_Path
			set /a x+=1
			set "KESkeyToUninstall[!x!]="!CleAtraiter!","!InstallLocationString_Value!""
		) else (
			REM comptage des cles KES dont la version est identiques à KES_Process_Started_Path
			set /a y+=1
			set "keyWithSamePathKESstarted[!y!]="!CleAtraiter!","!InstallLocationString_Value!""
		)
	)
)
Echo. >> %repTravail%logScriptInstallWithSecure.txt
if "!x!" NEQ "0" (
	echo Liste des repertoires de KES a desinstaller, Old version : >> %repTravail%logScriptInstallWithSecure.txt
	for /l %%a in (1, 1, !x!) do echo %%a - !KESkeyToUninstall[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
)
if "!y!" NEQ "0" (
	echo Liste des cles KES dont la version est identiques au KES running: >> %repTravail%logScriptInstallWithSecure.txt
	for /l %%a in (1, 1, !y!) do echo %%a - !keyWithSamePathKESstarted[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
)

Echo. >> %repTravail%logScriptInstallWithSecure.txt
REM calcul du nombre de correction detectee
SET /a Check_Install_KES_OK=!x!+!y!
if %Check_Install_KES_OK% EQU 0 (
	echo Etat de l installation de KES : %Check_Install_KES_OK% [X=!x! et Y=!y!] >> %repTravail%logScriptInstallWithSecure.txt
) else (
	echo Des elements de Kaspersky sont present sur "%COMPUTERNAME%" ... >> %repTravail%logScriptInstallWithSecure.txt
)

REM =====================================================================================================
REM Recuperation de la commande de desinstallation UninstallString
:CheckX
REM version KES differente de KES running
if !x! EQU 0 (GOTO CheckY)
echo Nombre de cles KES dont la version est differente de la version KES running sur le poste x="!x!" >> %repTravail%logScriptInstallWithSecure.txt
for /l %%a in (1, 1, !x!) do (
	for %%k in (!KESkeyToUninstall[%%a]!) do (
		SET valeur=%%k
		if /I "!valeur:~1,18!" EQU "HKEY_LOCAL_MACHINE" (
			SET CleAtraiter=!valeur!
			call :SUB_Get_UninstallStringKey !CleAtraiter!
			SET "KESkeyToUninstall[%%a]=!KESkeyToUninstall[%%a]!,"!uninstallStringCMD!""
			echo %%a - !KESkeyToUninstall[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
		)
	)
)
:CheckY
echo. >> %repTravail%logScriptInstallWithSecure.txt
REM version KES identique à KES running
if !y! EQU 0 (GOTO Install_Withsecure)
echo Recuperation de la valeur UninstallString pour les !y! cles detectees >> %repTravail%logScriptInstallWithSecure.txt
for /l %%a in (1, 1, !y!) do (
	for %%k in (!keyWithSamePathKESstarted[%%a]!) do (
		SET valeur=%%k
		if /I "!valeur:~1,18!" EQU "HKEY_LOCAL_MACHINE" (
			SET "CleAtraiter=!valeur!"
			call :SUB_Get_UninstallStringKey !CleAtraiter!
			SET "keyWithSamePathKESstarted[%%a]=!keyWithSamePathKESstarted[%%a]!,"!uninstallStringCMD!""
			echo %%a - !keyWithSamePathKESstarted[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
		)
	)
)
Echo. >> %repTravail%logScriptInstallWithSecure.txt


REM =====================================================================================================
REM Nettoyage des cles de registre KES detectées
:CleanupRegistry
if %Check_Install_KES_OK% EQU 0 (GOTO Install_Withsecure)
SET B=0
SET CleAtraiter=
REM Cleanup version KES differente
if !x! GTR 0 (
	for /l %%a in (1, 1, !x!) do (
		for %%k in (!KESkeyToUninstall[%%a]!) do (
			SET valeur=%%k
			if /I "!valeur:~1,18!" EQU "HKEY_LOCAL_MACHINE" (SET CleAtraiter=!valeur!)
			if /I !valeur! EQU "empty" (
				SET /A "B+=1"
				SET CleanUpCommands[!B!]= REG DELETE !CleAtraiter! /F
				SET CleanUpCommandsKey[!B!]=!CleAtraiter!
				set CleAtraiter=
			) else (
				if /I "!valeur:~1,11!" EQU "MSIEXEC.EXE" (
					SET /A "B+=1"
					SET CleanUpCommands[!B!]=!valeur:~1,-1! /quiet
					SET CleanUpCommandsKey[!B!]=!CleAtraiter!
				)
			)
		)
	)
)

REM Cleanup KES UninstallString registry empty
if !y! GTR 0 (
	for /l %%a in (1, 1, !y!) do (
		for %%k in (!keyWithSamePathKESstarted[%%a]!) do (
			SET valeur=%%k
			if /I "!valeur:~1,18!" EQU "HKEY_LOCAL_MACHINE" (SET CleAtraiter=!valeur!)
			if /I !valeur! EQU "empty" (
				SET /A "B+=1"
				SET CleanUpCommands[!B!]=REG DELETE !CleAtraiter! /F
				SET CleanUpCommandsKey[!B!]=!CleAtraiter!
			) else (
				if /I "!valeur:~1,11!" EQU "MSIEXEC.EXE" (SET "KES_Started_Uninstall_CMD=!valeur:~1,-1! /quiet")
			)
		)
	)
)
echo. >> %repTravail%logScriptInstallWithSecure.txt

REM Liste des commandes à traiter
if !B! GTR 0 (
	echo Nombre de commandes a executer avant installation de WithSecure: !B! >> %repTravail%logScriptInstallWithSecure.txt
	for /l %%a in (1, 1, !B!) do (echo [%%a] !CleanUpCommands[%%a]! >> %repTravail%logScriptInstallWithSecure.txt)
	echo. >> %repTravail%logScriptInstallWithSecure.txt
)
REM Execution de(s) commande(s) de desinstallation
if !B! GTR 0 (
	for /l %%a in (1, 1, !B!) do (
		if /I "!CleanUpCommands[%%a]:~0,11!" EQU "MSIEXEC.EXE" (
			echo DESINSTALLATION DE !CleanUpCommands[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
			call !CleanUpCommands[%%a]!  >> %repTravail%logScriptInstallWithSecure.txt
			Echo   Suppression de la cle de registre !CleanUpCommandsKey[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
			REG DELETE !CleanUpCommandsKey[%%a]! /F
		) else (
			echo EXECUTION DE !CleanUpCommands[%%a]! >> %repTravail%logScriptInstallWithSecure.txt
			!CleanUpCommands[%%a]!
		)
	)
)

GOTO CreateParamFile

REM =====================================================================================================
REM Functions
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
	SET "UninstallStringCMD=empty"
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
REM =====================================================================================================

:CreateParamFile
echo "%KES_Started_Uninstall_CMD%" >> %repTravail%cleanupKESAfterInstallWithSecureEndded.param
echo "%KES_Process_Started_Name%" >> %repTravail%cleanupKESAfterInstallWithSecureEndded.param
echo "%KES_Process_Started_Path%" >> %repTravail%cleanupKESAfterInstallWithSecureEndded.param

:FIN
echo Fin du script CleanupKESbeforeInstallWithSecure.cmd >> %repTravail%logScriptInstallWithSecure.txt
echo script endded > %repTravail%cleanupKESbeforeInstallWithSecureEndded.log
IF "%KESNOTrunning%" EQU "1" (echo KESNOTrunning >> %repTravail%cleanupKESbeforeInstallWithSecureEndded.log )
IF "%KESRegistryEmpty%" EQU "1" (echo KESRegistryEmpty >> %repTravail%cleanupKESbeforeInstallWithSecureEndded.log )