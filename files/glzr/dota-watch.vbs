' Starts dota-watch.ps1 without showing any window.
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{{GLZR_WIN}}\dota-watch.ps1""", 0, False
