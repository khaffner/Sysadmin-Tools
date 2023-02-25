# Sysadmin-Tools
A tool box of privately developed sysadmin tools I want to share.

There are many tool boxes like this scattered around the web, I'll try to only add tools doing things I've never seen anyone else do before.

---

### Get-IntuneWin32AppsFromLogs
Parses the local logs(!) for information about Win32Apps apps in your local Company Portal. I can't believe this is the most reliable local source of information. The original properties returned overlap greatly, if not 100%, with the Win32App model in Intune, but this function by default formats and cleans the output for human consumption. Use -Full parameter for all the details.
