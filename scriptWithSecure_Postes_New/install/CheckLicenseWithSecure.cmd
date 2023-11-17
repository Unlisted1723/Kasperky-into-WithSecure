@REM
@echo off
SETLOCAL EnableDelayedExpansion
@For /F Tokens^=6Delims^=^" %%A In ('WMIC OS Get Caption/Format:MOF')Do (Set "OperatingSystem=%%A")
@For /F "Tokens=3 Delims= " %%A In ("!OperatingSystem!")Do (
	IF "%%A" EQU "Server" ( Set "OperatingSystemType=SERVER" ) else ( SET "OperatingSystemType=STANDARD" )
)
IF "%OperatingSystemType%" EQU "STANDARD" ( SET "LicenceCode=MALB-A37B-LY9T-XGYQ-YF87" )
IF "%OperatingSystemType%" EQU "SERVER" ( SET "LicenceCode=T78C-TMGK-39XH-QLVA-LY8W" )
SET "NBloop=0"
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
echo. > %repTravail%CheckLicenseWithSecure.txt
echo DEBUT du script CheckLicenseWithSecure.cmd >> %repTravail%CheckLicenseWithSecure.txt

REM Recup des parametres
:RECUP_LOGS
SET "LicenseLogFile=%programdata%\F-Secure\Log\OneClient\FsLicenseNotifierPlugin.log"
if exist "%LicenseLogFile%" (
	REM echo %LicenseLogFile%
	for /F "delims=" %%v in ('type %LicenseLogFile%^|findstr /C:"Remind period"') DO (
		SET "LastLogFileLine=%%v"
	)
	SET LastLogFileLine=!LastLogFileLine:: =,!
	SET LastLogFileLine=!LastLogFileLine: =!
	REM Echo Liste des parametres de la ligne: "!LastLogFileLine!"
	REM Echo Liste des parametres de la ligne: "!LastLogFileLine!" >> %repTravail%CheckLicenseWithSecure.txt
	set /A i=0
	:loopprocess
	set /A i+=1
	for /F "tokens=1* delims=," %%A in ("!LastLogFileLine!") do (
	  SET TEMP=%%B
	  IF defined TEMP (
		set "LastLogFileLine=%%B"
		REM echo TEST %i%: "%%B"
		goto loopprocess
	  )
	)
	REM ECHO RemindPeriod: !LastLogFileLine!
	SET RemindPeriod=!LastLogFileLine:hour^(s^)=!
)
IF !RemindPeriod! GTR 0 (
	Echo Duree de la licence: %RemindPeriod% heures >> %repTravail%CheckLicenseWithSecure.txt
	Echo Duree de la licence: %RemindPeriod% heures
) else (
	Echo La duree de la licence a expiree %RemindPeriod% heures >> %repTravail%CheckLicenseWithSecure.txt
	Echo La duree de la licence a expiree %RemindPeriod% heures
)
CALL :SUB_Check_process_Started fsulprothoster.exe
if %Check_process_Started% EQU 1 (
	ECHO Licence OK
	GOTO FIN
) else (
	:RESET_Licence
	IF EXIST "%programfiles(x86)%\F-secure\PSB\fs_oneclient_logout.exe" (
		CALL :SUB_Check_process_Started fs_oneclient_logout.exe
		if %Check_process_Started% EQU 1 (
			REM Reset de la licence en cours ...
			TIMEOUT /T 5
			SET /A NBloop+=1
			IF NBloop EQU 6 (
				ECHO ERREUR Sortie de la boucle d attente >> %repTravail%CheckLicenseWithSecure.txt
				GOTO FIN
			)
			Echo Attente de la fin de fs_oneclient_logout.exe %NBloop%/6
			GOTO RESET_Licence
		) else (
			ECHO Reset de la licence ...  >> %repTravail%CheckLicenseWithSecure.txt
			ECHO EXECUTER la commande "%programfiles(x86)%\F-secure\PSB\fs_oneclient_logout.exe" --keycode %LicenceCode%
		)
	)
)
Goto FIN
REM "fsulprothoster.exe"
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
Echo "FIN du script CheckLicenseWithSecure.cmd" >> %repTravail%CheckLicenseWithSecure.txt