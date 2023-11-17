@REM
REM @echo off
SETLOCAL EnableDelayedExpansion
if /I "%~1" NEQ "" SET ARGUMENT=%~1
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
IF EXIST "%repTravail%TaskStatus.log" (del /F /S /Q "%repTravail%TaskStatus.log")
REM La presence du fichier de log logScriptCall.txt permet de verifier si le script a deja ete execute
IF EXIST "%repTravail%logScriptCall.txt" (SET "FirstExecutionTask=") ELSE (SET "FirstExecutionTask=OK")
SET "AVPStarted=NOK"
SET Userlogged=
Rem verif type de poste
@For /F Tokens^=6Delims^=^" %%A In ('WMIC OS Get Caption/Format:MOF')Do (Set "OperatingSystem=%%A")
@For /F "Tokens=3 Delims= " %%A In ("!OperatingSystem!")Do (
	IF "%%A" EQU "Server" ( Set "OperatingSystemType=SERVER" ) else ( SET "OperatingSystemType=STANDARD" )
)
Echo Systeme d exploitation: %OperatingSystemType% >> %repTravail%logScriptMainTask.txt
REM =====================================================
REM Detect User Logged
REM =====================================================
IF "%OperatingSystemType%" EQU "STANDARD" (
	IF not defined ARGUMENT ( CALL:SUB_DETECTuserLogged )
	if defined Userlogged (
		IF EXIST "%repTravail%Utilisateurpresent.xml" (
			echo "Process Explorer detecte %errorlevel%: Utilisateur present donc installation reportee au prochain demarrage du PC" >> %repTravail%logScriptMainTask.txt
			REM Create WithSecure Task at startup
			schtasks /create /TN "utilisateur" /XML "%repTravail%Utilisateurpresent.xml"
			schtasks /run /tn utilisateur
			schtasks /delete /tn utilisateur /f
			REM Create WithSecure Task Execute by user
			schtasks /end /TN "UserTaskWithSecure" /HRESULT
			schtasks /delete /TN "UserTaskWithSecure" /F
			schtasks /create /TN "UserTaskWithSecure" /XML "%repTravail%UserTaskWithSecure.xml"
			xcopy /R /Y "%repTravail%Installation nouvel Antivirus IMT Atlantique.lnk" "%PUBLIC%\Desktop\"
			GOTO FIN
		)
	) else (
		IF not defined ARGUMENT (
			Echo Aucun utilisateur connecte, on continue...  >> %repTravail%logScriptMainTask.txt
		) else (
			Echo Tache executee par l utilisateur sur %ARGUMENT% >> %repTravail%logScriptMainTask.txt
			REM msg * /w "Installation du nouvel antivirus en cours... (Estimation 4min)"
			del /F /S /Q "%PUBLIC%\Desktop\Installation nouvel Antivirus IMT Atlantique.lnk"
		)
	)
)

REM =====================================================
rem TESTs MSI installation in progress
REM =====================================================
echo.
echo "TEST autre installation en cours de package MSI" >> %repTravail%logScriptMainTask.txt
echo -------
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress" 2>NUL
IF %errorlevel% EQU 0 (
	echo on sort 4, Reboot en attente >> %repTravail%logScriptMainTask.txt
	msg * "Attention l installation de l antivirus WithSecure est reportee au prochain redemarrage du PC car une mise a jour prioritaire etait en attente. [2/4]" 
	exit -4
) else (echo Pas d autre installation en cours, on continue... >> %repTravail%logScriptMainTask.txt)
echo. >> %repTravail%logScriptMainTask.txt

REM =====================================================================================================
REM Verif de l etat de l installation de WithSecure
REM =====================================================================================================
Echo. >> %repTravail%logScriptCall.txt
echo "Execution de la tache planifiee withSecure %repTravail%schatks.cmd" >> %repTravail%logScriptCall.txt
Echo "%DATE% %TIME%" >> %repTravail%logScriptCall.txt
Echo "FirstExecutionTask: %FirstExecutionTask%" >> %repTravail%logScriptCall.txt
REM verif presence de Withsecure
if EXIST "C:\Program Files (x86)\F-Secure\PSB\ui\wsmain.exe" (
	Echo "Fichiers Withsecure presents" >> %repTravail%logScriptCall.txt
	REM verif execution des services de Withsecure
	SET "ProcessName=fshoster32.exe"
	CALL :SUB_Check_process_Started !ProcessName!
	if "!Check_process_Started!" EQU "1" (
		Echo "WithSecure Fonctionne: !Check_process_Started!" >> %repTravail%logScriptCall.txt
		SET "WithsecureStarted=OK"
		REM verification de la licence WithSecure
		If exist "%repTravail%CheckLicenseWithSecure.cmd" CALL "%repTravail%CheckLicenseWithSecure.cmd" >> %repTravail%logScriptCall.txt
		GOTO UninstallCurrentKaspersky
	) else (
		Echo Fichiers Withsecure present mais ne demarre pas "!Check_process_Started!" >> %repTravail%logScriptCall.txt
		SET "WithsecureStarted="
	)
)
If "%WithsecureStarted%" EQU "OK" GOTO CleanupKESbeforeInstallWithSecure
Rem WithSecure execution failed: Remove it
Echo "Suppression de WithSecure" >> %repTravail%logScriptCall.txt
If exist "%repTravail%RemoveWithSecure.cmd" Call "%repTravail%RemoveWithSecure.cmd" >> %repTravail%logScriptCall.txt

REM =====================================================================================================
REM  -1 Cleanup KES before installation withsecure
REM =====================================================================================================
:CleanupKESbeforeInstallWithSecure
Echo Execution du script cleanupKESbeforeInstallWithSecure.cmd >> %repTravail%logScriptCall.txt
echo "1 - Verif et nettoyage des installations de Kaspersky" >> %repTravail%logScriptCall.txt
If exist "%repTravail%cleanupKESbeforeInstallWithSecure.cmd" call "%repTravail%cleanupKESbeforeInstallWithSecure.cmd" >> %repTravail%logScriptCall.txt
SET ComptWaitLoop=0
REM Waiting Cleanup KES before Install Withsecure script endded
:DetectCleanupBeforeInstEndded
if EXIST "%repTravail%cleanupKESbeforeInstallWithSecureEndded.log" (
	Echo "1 - Fin du nettoyage des installations de Kaspersky sur %COMPUTERNAME%" >> %repTravail%logScriptCall.txt
	del /F /S /Q "%repTravail%cleanupKESbeforeInstallWithSecureEndded.log
	GOTO UninstallCurrentKaspersky
) else (
	set /a ComptWaitLoop+=1
	TIMEOUT /T 5 /NOBREAK
	if "%ComptWaitLoop%" NEQ "6" (
		GOTO DetectCleanupBeforeInstEndded
	) else (
		Echo "1 - Echec du nettoyage de KES avant installation de WithSecure" >> %repTravail%logScriptCall.txt
		GOTO FIN
	)
)

REM =====================================================================================================
REM  -2 Uninstall current Kaspersky
REM =====================================================================================================
:UninstallCurrentKaspersky
Echo "Debut de la Desinstallation de Kaspersky sur %COMPUTERNAME%: Execution du script UnInstallCurrentKES.CMD" >> %repTravail%logScriptCall.txt
If exist "%repTravail%UnInstallCurrentKES.CMD" CALL "%repTravail%UnInstallCurrentKES.CMD" >> %repTravail%logScriptCall.txt
Echo "Fin de la Desinstallations de Kaspersky sur %COMPUTERNAME%" >> %repTravail%logScriptCall.txt

REM =====================================================================================================
REM  -2 Installation de Withsecure
REM =====================================================================================================
:INSTALL_WithSecure
If "%WithsecureStarted%" EQU "OK" (
	Echo "2 - WithSecure est deja installee. Donc execution du nettoyage apres install" >> %repTravail%logScriptCall.txt
	GOTO CleanupKESafterInstallWithSecure
)
Echo "2 - Debut de l installation de WithSecure..." >> %repTravail%logScriptCall.txt
Echo %DATE% %TIME% >> %repTravail%logScriptCall.txt
msg * /w "Analyse de votre poste terminee. Debut de l installation de l antivirus ... [1/4] "
If exist "%repTravail%installWithSecure.cmd" call "%repTravail%installWithSecure.cmd" >> %repTravail%logScriptCall.txt
REM Waiting Install Withsecure Endded
REM Detect Install WithSecure Endded and OK
if EXIST "%repTravail%InstallWithSecureEndded.log" (
	Echo "2 - Fin du script installWithSecure.cmd d installation de WithSecure sur %COMPUTERNAME%" >> %repTravail%logScriptCall.txt
	rem Message de fin d installalation correct
	msg * /w "Encore une minute de patience pendant la suppression les dernieres traces de votre ancien antivirus. Un redemarrage du PC sera effectue automatiquement ... [3/4]"
	DEL /F /S /Q "%repTravail%InstallWithSecureEndded.log"
	SET "WithSecureInstallationExecuted=OK"
) else (
	Echo "2 - Echec de l installation de WithSecure" >> %repTravail%logScriptCall.txt
	rem Message d echec de l installalation
	msg * /w "/!\ Attention. ECHEC de l installation du nouvel antivirus. Une nouvelle tentative sera executee au prochain redemarrage du PC."
	GOTO FIN
)

REM =====================================================================================================
REM  -3 Cleanup Kaspersky apres Install WithSecure
REM =====================================================================================================
:CleanupKESafterInstallWithSecure
REM Detection de Kaspersky KES apres installation de Withsecure
SET "ProcessName=avp.exe"
CALL :SUB_Check_process_Started %ProcessName%
if "%Check_process_Started%" EQU "1" (
	echo. >> %repTravail%logScriptCall.txt
	Echo "Kaspersky AVP.EXE Fonctionne toujours apres l installation de WithSecure" >> %repTravail%logScriptCall.txt
	SET "AVPStarted=OK"
	if "%WithSecureStarted%" EQU "OK" (
		echo "WithSecure et Kaspersky sont executes en meme temps" >> %repTravail%logScriptCall.txt
	)
)
if EXIST "%repTravail%cleanupKESAfterInstallWithSecureEndded.param" (
	echo. >> %repTravail%logScriptCall.txt
	Echo "Execution du script cleanupKESafterInstallWithSecure.cmd" >> %repTravail%logScriptCall.txt
	If exist "%repTravail%cleanupKESafterInstallWithSecure.cmd" Call "%repTravail%cleanupKESafterInstallWithSecure.cmd" >> %repTravail%logScriptCall.txt
	Echo "Nettoyage apres installation est termine ..." >> %repTravail%logScriptCall.txt
	echo. >> %repTravail%logScriptCall.txt
) else ( Echo Pas d execution du script cleanupKESafterInstallWithSecure.cmd car le fichier PARAM est absent. >> %repTravail%logScriptCall.txt )
REM Derniere detection de Kaspersky KES apres execution du script cleanupKESafterInstallWithSecure.cmd
SET "ProcessName=avp.exe"
CALL :SUB_Check_process_Started %ProcessName%
if "%Check_process_Started%" EQU "1" (
	Echo "AVP.EXE Fonctionne toujours apres cleanupKESafterInstallWithSecure" >> %repTravail%logScriptCall.txt
	IF "%WithSecureInstallationExecuted%" EQU "OK" ( GOTO REBOOT )
)
REM Detection de l agent Kaspersky apres execution du script cleanupKESafterInstallWithSecure.cmd
:DetectKLNagent
Echo "Detection du fonctionnement de l agent Kaspersky" >> %repTravail%logScriptCall.txt 
SET "ProcessName=klnagent.exe"
:BoucleDetectKLNagent
CALL :SUB_Check_process_Started %ProcessName%
if "%Check_process_Started%" EQU "1" (
	Echo "L agent Kaspersky fonctionne correctement apres cleanupKESafterInstallWithSecure" >> %repTravail%logScriptCall.txt
	GOTO Delfiles
)
IF "%WithSecureInstallationExecuted%" EQU "OK" ( GOTO REBOOT )
SET /a CountDetectKLNagent+=1
if "%CountDetectKLNagent%" NEQ "6" (
	C:\Windows\System32\sc.exe start KLNAgent
	TIMEOUT /T 5
	GOTO BoucleDetectKLNagent
) else (
	Echo "L agent Kaspersky ne fonctionne pas apres cleanupKESafterInstallWithSecure: reinstallation de l agent Kaspersky" >> %repTravail%logScriptCall.txt
	If exist "%repTravail%ReinstallKLNagent.cmd" CALL "%repTravail%ReinstallKLNagent.cmd" >> %repTravail%logScriptCall.txt
	if "%FirstExecutionTask%" EQU "OK" GOTO REBOOT
)


REM =====================================================================================================
REM  -3 Force la suppression des résidus de Kaspersky KES
REM =====================================================================================================
:Delfiles
echo "Nettoyage du deploiement de WithSecure" >> %repTravail%logScriptCall.txt
REM message apres installation de WithSecure et le Reboot du poste
If "%WithSecureInstallationExecuted%" EQU "OK" (
	rem message de FIN
	msg * /w "Merci d avoir patiente. Vous disposez maintenant du nouvel antivirus de l IMT Atlantique nomme WithSecure [4/4]"
)
If not exist "%repTravail%installWithSecure.cmd" GOTO DeleteALL

REM Delete All Deployment Files except KeepFiles
SET "KeepFiles=MainTask.cmd,cleanupKESbeforeInstallWithSecure.cmd,CheckLicenseWithSecure.cmd,logScriptCall.txt,logScriptInstallWithSecure.txt,AppRemover_ToBeDelAfterReboot.bat,AppRemover_RunBatchSilently.vbs"
for /R "%repTravail%" %%F in (*.*) do (
	SET "PathNameFile=%%~pF"
	SET "NameFile=%%~nxF"
	REM Echo test: !PathNameFile!!NameFile!
	Call :SUB_Compare "!NameFile!"
	if "!SameFile!" EQU "0" (
		SET "CompletNameFile=!PathNameFile!!NameFile!"
		del /F /S /Q "!CompletNameFile!"
		rmdir "!CompletNameFile!" /s /q
	)
)
schtasks /delete /TN "UserTaskWithSecure" /F
IF exist "C:\Windows\system32\Utilisateurpresent.exe" (DEL /F /S /Q "C:\Windows\system32\Utilisateurpresent.exe")
IF exist "C:\Windows\system32\InstallWithSecure\UtilisateurpresentV2.exe" (DEL /F /S /Q "C:\Windows\system32\UtilisateurpresentV2.exe")
IF exist "%programdata%\InstallWithSecure\Utilisateurpresent.exe" (DEL /F /S /Q "%programdata%\InstallWithSecure\Utilisateurpresent.exe")
IF exist "%programdata%\InstallWithSecure\UtilisateurpresentV2.exe" (DEL /F /S /Q "%programdata%\InstallWithSecure\UtilisateurpresentV2.exe")
IF exist "%programdata%\InstallWithSecure" (RD /S /Q "%programdata%\InstallWithSecure")
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Kaspersky Endpoint Security" /f
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Kaspersky Event Log" /f
GOTO REBOOT

:DeleteALL
echo "Fin, Nettoyage de Kaspersky" >> %repTravail%logScriptCall.txt
REM les repertoires d installation de Kaspersky
IF exist "%ProgramData%\Kaspersky Lab\KES" (
	del /F /S /Q "%ProgramData%\Kaspersky Lab\KES\"
	rd /S /Q "%ProgramData%\Kaspersky Lab\KES\"
	Echo Nettoyage de "%ProgramData%\Kaspersky Lab\KES\" >> %repTravail%logScriptCall.txt
)
IF exist "%ProgramData%\Kaspersky Lab\Kaspersky Security for Windows Server" (
	setacl -on "%ProgramData%\Kaspersky Lab\Kaspersky Security for Windows Server" -ot file -actn setowner -ownr "n:Administrateurs" -rec
	echo y | cacls "%ProgramData%\Kaspersky Lab\Kaspersky Security for Windows Server" /e /t /c /g "tout le monde":F
	del /F /S /Q "%ProgramData%\Kaspersky Lab\Kaspersky Security for Windows Server\"
	rd /S /Q "%ProgramData%\Kaspersky Lab\Kaspersky Security for Windows Server\"
	Echo Nettoyage de "%ProgramData%\Kaspersky Lab\Kaspersky Security for Windows Server\" >> %repTravail%logScriptCall.txt
)
IF exist "%ProgramData%\Kaspersky Lab" (
	del /F /S /Q "%ProgramData%\Kaspersky Lab\"
	rd /S /Q "%ProgramData%\Kaspersky Lab\"
	Echo Nettoyage de "%ProgramData%\Kaspersky Lab\" >> %repTravail%logScriptCall.txt
)
IF exist "%ProgramData%\KasperskyLab" (
	del /F /S /Q "%ProgramData%\KasperskyLab\"
	rd /S /Q "%ProgramData%\KasperskyLab\"
	Echo Nettoyage de "%ProgramData%\KasperskyLab\" >> %repTravail%logScriptCall.txt
)
IF exist "C:\Program Files (x86)\Common Files\Kaspersky Lab" (
	del /F /S /Q "C:\Program Files (x86)\Common Files\Kaspersky Lab\"
	rd /S /Q "C:\Program Files (x86)\Common Files\Kaspersky Lab\"
	Echo Nettoyage de "C:\Program Files (x86)\Common Files\Kaspersky Lab\" >> %repTravail%logScriptCall.txt
)
echo "Nettoyage des eventLog de Kaspersky" >> %repTravail%logScriptCall.txt
REM suppression des eventlogs
del /F /S /Q "C:\Windows\System32\winevt\Logs\Kaspersky Endpoint Security.evtx"
del /F /S /Q "C:\Windows\System32\winevt\Logs\Kaspersky Event Log.evtx"
del /F /S /Q "C:\Windows\System32\winevt\Logs\Kaspersky-Security-*.evtx"
echo "Nettoyage des eventLog de Kaspersky termine " >> %repTravail%logScriptCall.txt
REM suppression du Menu demarrer de Windows
echo "Nettoyage du menu demarrer de WithSecure" >> %repTravail%logScriptCall.txt
ren "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\WithSecure™ Elements Agent" "WithSecure Elements Agent"
ren "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\WithSecure Elements Agent\Outil d'assistance WithSecure™" "Outil d'assistance WithSecure"
ren "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\WithSecure Elements Agent\WithSecure™ Elements Agent" "WithSecure Elements Agent"
for /f delims^=^ eol^= %%f in (' dir "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\WithSecure Elements Agent" /s /b ') do (
	move "%%f" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Sécurité"
)
rd /S /Q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Sécurité\Antivirus"
rd /S /Q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\WithSecure Elements Agent"
echo "Nettoyage du menu demarrer de WithSecure termine " >> %repTravail%logScriptCall.txt
Rem autodestruction de la tache planifiee
IF exist "C:\WINDOWS\TEMP\AppRemover_RunBatchSilently.vbs" ( wscript.exe "C:\WINDOWS\TEMP\AppRemover_RunBatchSilently.vbs" "C:\WINDOWS\TEMP\AppRemover_ToBeDelAfterReboot.bat" )
echo "Nettoyage du menu demarrer de WithSecure termine " >> %repTravail%logScriptCall.txt
reg query HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce /v AppRemover
If "%errorlevel%" EQU "0" (reg delete HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce /v AppRemover)
schtasks /delete /TN "\WithSecure" /F
echo "Nettoyage des derniers fichiers " >> %repTravail%logScriptCall.txt
:BouleDeleteAll
del /F /Q "%repTravail%*"
GOTO FIN

REM =====================================================================================================
REM FONCTIONS
REM =====================================================================================================
REM Check User logged
:SUB_DETECTuserLogged
echo "verfication utilisateur present" >> %repTravail%logScriptCall.txt
tasklist /FI "imagename eq explorer.exe" | findstr PID > NUL 2>&1
if "%ERRORLEVEL%" EQU "0" (SET "Userlogged=OK") else (
	echo "Process Explorer absent: Pas d utilisateur present donc on continue ..." >> %repTravail%logScriptCall.txt
	SET Userlogged=
)
EXIT /B 0
REM =====================================================
REM Check process started
:SUB_Check_process_Started
if /I "%~1"=="" EXIT /B 0
SET ProcessName=%~1
tasklist /FI "imagename eq %ProcessName%" | findstr PID > NUL 2>&1
if %ERRORLEVEL% EQU 0 ( SET "Check_process_Started=1" ) else ( SET "Check_process_Started=0")
EXIT /B 0
REM =====================================================
:SUB_Compare
if /I "%~1"=="" EXIT /B 0
SET "SameFile=0"
SET FichierAcomparer=%~1
SET "ListFichiersExclus=%KeepFiles%"
:boucleKeepFiles
for /f "tokens=1,* delims=," %%a IN ("%ListFichiersExclus%") DO (
	SET "NextKeepFile=%%b"
	REM ECHO Compare: !FichierAcomparer! et %%a
	if "!FichierAcomparer!" EQU "%%a" (
		REM ECHO Compare: "!FichierAcomparer!" EQU "%%a"
		SET "SameFile=1"
		EXIT /B 0
	)
)
if "!NextKeepFile!" NEQ "" (
	SET "ListFichiersExclus=!NextKeepFile!"
	GOTO boucleKeepFiles
)
EXIT /B 0
REM =====================================================================================================
REM Fin des fonctions
REM =====================================================================================================

REM =====================================================================================================
REM FIN
REM =====================================================================================================
:REBOOT
echo verification si le reboot du poste est possible. >> %repTravail%logScriptCall.txt
IF "%OperatingSystemType%" EQU "STANDARD" (
	CALL:SUB_DETECTuserLogged
	if defined Userlogged (
		echo "Process Explorer detecte %errorlevel%: Utilisateur present donc REBOOT annule !" >> %repTravail%logScriptCall.txt
		schtasks /create /TN "utilisateur" /XML "%repTravail%UtilisateurpresentV2.xml"
		schtasks /run /tn utilisateur
		schtasks /delete /tn utilisateur /f
		GOTO FIN
	)
)
Echo FirstExecutionTask: %FirstExecutionTask%  >> %repTravail%logScriptCall.txt
IF "%FirstExecutionTask%" EQU "OK" (
	echo "Aucun utilisateur detecte donc REBOOT du poste..." >> %repTravail%logScriptCall.txt
	msg * /w "Redemarrage de votre poste dans 10 secondes ..."
	shutdown /r /t 10 /f /c "Installation de WithSecure"
)

:FIN
Echo ===================================================================================================== >> %repTravail%logScriptCall.txt
echo "Fin de la tache planifiee schatks" >> %repTravail%logScriptCall.txt
Echo ===================================================================================================== >> %repTravail%logScriptCall.txt
Echo. >> %repTravail%logScriptCall.txt