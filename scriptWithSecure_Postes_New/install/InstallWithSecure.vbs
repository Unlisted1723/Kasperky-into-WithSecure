'Script d execution de l installation de WithSecure par l utilisateur
'Ce script permet de créer dans le journal des évènements de Windows une alerte permettant de déclencher la tache planifiee par cette action

Dim WshShell, myDateString, mytimestring
Set WshShell = CreateObject("WScript.Shell")

'set the date and time into variables
myDateString = Date()
mytimestring = Time()

WshShell.LogEvent 4, "le " & myDateString & " a " & mytimestring & vbCrLf & "Execution de l installation de WithSecure par l utilisateur"
WshShell.Run("""%programdata%\InstallWithSecure\UtilisateurExecution.exe""")
Set WshShell = Nothing