SETLOCAL EnableDelayedExpansion
REM =====================================================
REM Declenchement manuel de l installation par l utilisateur
REM =====================================================
schtasks /run /tn UserTaskWithSecure
schtasks /create /TN "Message" /XML "%repTravail%UserTaskWithSecureMessage.xml"
schtasks /run /tn Message
schtasks /delete /tn Message /f