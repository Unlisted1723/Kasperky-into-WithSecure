'Script d execution de l installation de WithSecure par l utilisateur
'Ce script permet de cr�er dans le journal des �v�nements de Windows une alerte permettant de d�clencher la tache planifiee par cette action

Dim WshShell, myDateString, mytimestring
Set WshShell = CreateObject("WScript.Shell")

'set the date and time into variables
myDateString = Date()
mytimestring = Time()

WshShell.LogEvent 4, "le " & myDateString & " a " & mytimestring & vbCrLf & "Execution de l installation de WithSecure par l utilisateur"
WshShell.Run("""%programdata%\InstallWithSecure\UtilisateurExecution.exe""")
Set WshShell = Nothing