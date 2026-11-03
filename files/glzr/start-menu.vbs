' Opens the Windows Start menu (Ctrl+Esc) without showing a window, then keeps the taskbar hidden.
' Used by the Zebar bar button.
Set sh = CreateObject("WScript.Shell")
sh.SendKeys "^{ESC}"
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{{GLZR_WIN}}\taskbar-rehide.ps1""", 0, False
