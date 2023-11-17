@REM
REM@echo off
SETLOCAL EnableDelayedExpansion
for /f %%i in ('echo %~sf0') DO SET repTravail=%%~dpi
if EXIST "%repTravail%InstallWithSecureEndded.log" (del /F /S /Q "%repTravail%InstallWithSecureEndded.log")
SET WithsecureStarted=0
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

echo. >> %repTravail%logScriptInstallWithSecure.txt
echo DEBUT du script installWithSecure.cmd sur %OperatingSystem% : %OperatingSystemType%
echo DEBUT du script installWithSecure.cmd sur %OperatingSystem% : %OperatingSystemType% >> %repTravail%logScriptInstallWithSecure.txt
date /T >> %repTravail%logScriptInstallWithSecure.txt
time /T >> %repTravail%logScriptInstallWithSecure.txt

REM INSTALLATION de With Secure ?
CALL :SUB_CheckWithSecureStarted
if %WithsecureStarted% EQU 1 (
	if EXIST "C:\Program Files (x86)\F-Secure\PSB\ui\wsmain.exe" (
		Echo WithSecure est deja installe et fonctionne >> %repTravail%logScriptInstallWithSecure.txt
		GOTO Fin
	)
)
REM =====================================================
REM TEST acces internet
REM =====================================================
:TEST_ACCES_INTERNET
set /a ComptGoogle=0
set ProxyAutoDetect=
Rem 1er Test: Acces Internet sans Proxy
CALL :SUB_INTERNET_TEST
IF "%InternetAcces%" EQU "OK" Goto Install_Withsecure

Rem 2eme TEST: Acces Internet avec proxy configuré manuellement
set Valeur=
for /f "delims=" %%k in ('C:\Windows\System32\netsh.exe winhttp import proxy source^=ie^|findstr "proxy"') do (SET Valeur="%%k")
if defined Valeur (for /f "tokens=2,* delims=:" %%p in (%Valeur%) do (SET ProxyAutoDetect=%%p:%%q))
REM if defined ProxyAutoDetect (SET ProxyAutoDetect=%ProxyAutoDetect: =%)
Call :SUB_doClean %ProxyAutoDetect% ProxyAutoDetect
REM Verification du resultat de la detection du proxy
if defined ProxyAutoDetect (
	echo Proxy setting by admin Detected : %ProxyAutoDetect% >> %repTravail%logScriptInstallWithSecure.txt
	CALL :SUB_INTERNET_TEST
) else (
	echo Proxy setting by admin Not Detected >> %repTravail%logScriptInstallWithSecure.txt
)
IF "%InternetAcces%" EQU "OK" Goto Install_Withsecure

REM 3eme TEST: Acces Internet avec proxy configuré en AutoDetect
REM https://emeaie.azurewebsites.net/pierrelc/
for /f "tokens=4 delims= " %%f in ('%repTravail%autoprox.exe -a^|findstr WPAD') do (Set "ResultAutoProx=%%f")
if defined ResultAutoProx (Call :SUB_doClean %ResultAutoProx% ResultAutoProx)
If defined ResultAutoProx (
	SET "ResultAutoProx=%ResultAutoProx: =%"
	IF "%ResultAutoProx:~0,4%" EQU "http" (SET "ProxyWPAD_URL=%ResultAutoProx%")
)
if defined ProxyWPAD_URL (
	Echo WPAD detecte: %ProxyWPAD_URL% >> %repTravail%logScriptInstallWithSecure.txt
	Rem Detection du proxy via le Wpad
	Echo Commande: %repTravail%autoprox.exe -o -u:http://google.fr -p:%ProxyWPAD_URL% >> %repTravail%logScriptInstallWithSecure.txt
	FOR /F "delims=" %%f in ('%repTravail%autoprox.exe -o -u:http://google.fr -p:%ProxyWPAD_URL%') do (
		SET "AutoProxResult=%%f"
		Echo !AutoProxResult! >> %repTravail%logScriptInstallWithSecure.txt
		IF "!AutoProxResult:~0,5!" EQU "PROXY" (SET "ProxyAutoDetect=!AutoProxResult!")
	)
)
if defined ProxyAutoDetect (
	for /f "tokens=2 delims= " %%f in ("%ProxyAutoDetect%") do (set ProxyAutoDetect=%%f)
)
if defined ProxyAutoDetect (
	Echo Resultat: %ProxyAutoDetect% >> %repTravail%logScriptInstallWithSecure.txt
	CALL :SUB_INTERNET_TEST
)
IF "%InternetAcces%" NEQ "OK" (
	msg * "Attention l'installation de votre nouvel antivirus necessite une connexion a internet. Une nouvelle tentative sera effectuee au prochain redemarrage du PC."
	Goto Fin
)

:Install_Withsecure
echo Nettoyage Installation precedente de WithSecure *.tmp >> %repTravail%logScriptInstallWithSecure.txt
FOR /D %%r IN ("C:\WINDOWS\TEMP\fs*.tmp") DO del /S /F /Q %%r
FOR /D %%r IN ("C:\WINDOWS\TEMP\fs*.tmp") DO (RD /S /Q %%r)
echo Nettoyage Installation precedente de WithSecure dans Uninstall Registry >> %repTravail%logScriptInstallWithSecure.txt

echo Nettoyage Installation precedente de WithSecure dans program files >> %repTravail%logScriptInstallWithSecure.txt
if EXIST "C:\Program Files (x86)\F-Secure" (
	del /S /F /Q "C:\Program Files (x86)\F-Secure" >> %repTravail%logScriptInstallWithSecure.txt
	RD /S /Q "C:\Program Files (x86)\F-Secure" >> %repTravail%logScriptInstallWithSecure.txt
	FOR /D %%r IN ("C:\Program Files (x86)\F-Secure") DO (RD /S /Q %%r >> %repTravail%logScriptInstallWithSecure.txt)
)
echo Debut de l installation de WithSecure >> %repTravail%logScriptInstallWithSecure.txt
msg * /w "Attention, L installation de votre nouvel antivirus est en cours. Merci de patienter et de ne pas utiliser votre poste. Un redemarrage du PC sera effectue une fois l'installation terminee..." 
REM Utilisation du PROXY ?
if defined ProxyAutoDetect (
	echo Installation de WithSecure avec configuration du proxy >> %repTravail%logScriptInstallWithSecure.txt
	MSIEXEC.EXE /I %repTravail%%WithSecureInstaller% /qn /l* %repTravail%logMSIwithsecure.txt PROXY_SERVER=http://%ProxyAutoDetect%
) else (
	echo Installation de WithSecure sans proxy >> %repTravail%logScriptInstallWithSecure.txt
	MsiExec.exe /I %repTravail%%WithSecureInstaller% /q /l* %repTravail%logMSIwithsecure.txt
)
set MSIerror=%errorlevel%
echo Code Erreur MSI %errorlevel% >> %repTravail%logScriptInstallWithSecure.txt

REM Boucle d attente de fin d installation de WithSecure
echo En attente de la fin du programme d installation de WithSecure >> %repTravail%logScriptCall.txt
:Boucle_WithsecureInstaller
Call :SUB_Check_process_Started oneclient_sidegrader.exe
if %Check_process_Started% EQU 1 (
	TIMEOUT /T 5
	GOTO Boucle_WithsecureInstaller
)
echo Installation de WithSecure Terminee: Fin du programme oneclient_sidegrader.exe
echo Installation de WithSecure Terminee: Fin du programme oneclient_sidegrader.exe >> %repTravail%logScriptInstallWithSecure.txt
REM verification du bon demarrage de WithSecure
CALL :SUB_CheckWithSecureStarted
if %WithsecureStarted% EQU 1 (
	SET withsecureInstalled=1
	Echo WithSecure fonctionne : Verification du nettoyage de Kaspersky puis REBOOT ... >> %repTravail%logScriptInstallWithSecure.txt
	msg * /w "Attention, l installation de votre nouvel antivirus est terminee. Un redemarrage de votre PC sera effectue dans quelques secondes ..."
	echo "OK" >> %repTravail%InstallWithSecureEndded.log
	GOTO FIN
) else (
	echo ATTENTION. Le demarrage de WithSecure n'est pas detecte >> %repTravail%logScriptInstallWithSecure.txt
	msg * /w "Attention, Echec de l installation de votre nouvel antivirus. Une nouvelle tentative sera effectuee au prochain redemarrage du PC."
	GOTO FIN
)
GOTO Fin
REM =====================================================================================================
REM Functions
REM =====================================================
:SUB_doClean input output
    setlocal enableextensions enabledelayedexpansion
    set "map=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.-:/"
    set "input=%~1"
    set "output="

rem Step 1 - Remove critical delimiters
(
:purgeCritical
    for /L %%z in (1 1 10) do (
        for /f tokens^=1^-9^,^*^ delims^=^=^"^"^~^;^,^&^*^%%^!^(^)^<^>^^ %%a in ("!input!") do ( 
            set "output=!output!%%a%%b%%c%%d%%e%%f%%g%%h%%i"
            set "input=%%j" 
        )
        if not defined input goto outPurgeCritical
    )
    goto purgeCritical
)
:outPurgeCritical

rem Step 2 - remove any remaining special character
(
:purgeNormal
    for /L %%z in (1 1 10) do (
        set "pending="
        for /f "tokens=1,* delims=%map%" %%a in ("!output!") do (
            set "output=!output:%%a=!"
            set "pending=%%b"
        )
        if not defined pending goto outPurgeNormal
    )
    goto purgeNormal
)
:outPurgeNormal

    endlocal & set "%~2=%output%"
EXIT /B 0


REM Function Convertion en majuscule
:SUB_Capital_Letter
if /I "%~1"=="" EXIT /B 0
for /F "delims=" %%a in (%~1) do (
   set "line=%%a"
   for %%b in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
      set "line=!line:%%b=%%b!"
   )
   echo !line!
   SET "%~2=!line!"
)
EXIT /B 0

REM =====================================================
REM Check process started
:SUB_Check_process_Started
if /I "%~1"=="" EXIT /B 0
SET ProcessName=%~1
SET Check_process_Started=0
tasklist /FI "imagename eq %ProcessName%" | findstr PID > NUL 2>&1
if %ERRORLEVEL% EQU 0 (SET Check_process_Started=1) else (SET Check_process_Started=0)
EXIT /B 0

REM =====================================================
REM Check withsecure Started
:SUB_CheckWithSecureStarted
set /a ComptWaitStartAgent=0
:Boucle_WithsecureStarted
Call :SUB_Check_process_Started fshoster32.exe
if %Check_process_Started% EQU 0 (
	SET WithsecureStarted=0
	set /a ComptWaitStartAgent+=1
	TIMEOUT /T 5
	if %ComptWaitStartAgent% NEQ 6 (GOTO Boucle_WithsecureStarted)
) else (
	SET WithsecureStarted=1
	)
EXIT /B 0

:SUB_INTERNET_TEST
Rem TEST PING Google
SET InternetAcces=
if defined ProxyAutoDetect (
	Rem Test avec Proxy
	Echo Test acces internet avec Proxy...  >> %repTravail%logScriptInstallWithSecure.txt
	CALL %repTravail%curl.exe -Isf google.fr -x %ProxyAutoDetect% > %repTravail%testHTML.log
	for /f "tokens=2 delims= " %%x in (%repTravail%testHTML.log) do (
		If "%%x" EQU "301" (
			SET InternetAcces=OK
			GOTO Result
		)
	)
) else (
	Rem Test sans Proxy
	Echo Test acces internet sans Proxy...  >> %repTravail%logScriptInstallWithSecure.txt
	CALL %repTravail%curl.exe -Isf google.fr > %repTravail%testHTML.log
	for /f "tokens=2 delims= " %%x in (%repTravail%testHTML.log) do (
		If "%%x" EQU "301" (
			SET InternetAcces=OK
			GOTO Result
		)
	)
)
:Result
If defined InternetAcces (
	echo Connected to the internet. [%ERRORLEVEL%] >> %repTravail%logScriptInstallWithSecure.txt
) else (
	if defined ProxyAutoDetect (
		echo Echec du test d acces a internet via le proxy %ProxyAutoDetect%. [%ERRORLEVEL%] >> %repTravail%logScriptInstallWithSecure.txt
	) else (
		echo Echec du test d acces a internet sans proxy. [%ERRORLEVEL%] >> %repTravail%logScriptInstallWithSecure.txt
	)
)
DEL /F /Q %repTravail%testHTML.log
EXIT /B 0

REM =====================================================================================================
REM Fin des fonctions
REM =====================================================================================================

:FIN
date /T  >> %repTravail%logScriptInstallWithSecure.txt
time /T  >> %repTravail%logScriptInstallWithSecure.txt
echo FIN du script installWithSecure.cmd >> %repTravail%logScriptInstallWithSecure.txt
echo. >> %repTravail%logScriptInstallWithSecure.txt