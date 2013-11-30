rem @echo off
rem ######################################################
rem
rem Thorsten Bruhns (Thorsten.Bruhns@opitz-consulting.de)
rem $Id: online_level0.bat 445 2012-08-22 19:57:42Z tbr $
rem
rem Scheuuled tasks anlegen:
rem SCHTASKS /Create /F  /rl highest /SC weekly /D SUN,MON,TUE,WED,THU,FRI /ru "System"  /TN Oracle_Backup<DB-Name>\RMAN_Level1 /ST 03:00:00 /TR c:\temp\1.cmd 
rem
rem schtasks /query /fo table /tn Oracle_Backup\<DBName>\rman_level0
rem
rem SCHTASKS /Create /F  /rl highest /SC hourly  /ru "System" /MO 2 /ST 02:45:00 /TN Oracle_Backup\<DB-Name>\RMAN_Arch /TR c:\temp\1.cmd

rem ######################################################

set oracle_sid=
set rmanskript=online_level0
set rmantarget=/ as sysdba
set rmancatalog=nocatalog

set lsPath=%~dp0
set logpath=%lsPath%log

set rmanskriptname=%rmanskript%.rman
set rmancmdfile=%lsPath%%rmanskriptname%
set nls_date_format=yyyy.mm.dd hh24:mi:ss
set jahr=%date:~-4%
set tag=%date:~-7,2%
set monat=%date:~-10,2%
set logfile=%logpath%\log\%ORACLE_SID%_%rmanskript%_%jahr%%monat%%tag%.log

rman %rmantarget% %rmancatalog% cmdfile="%rmancmdfile%" logfile="%logfile%" append

set retcode=%errorlevel%
if %retcode% neq 0 goto Fehler

goto end
:Fehler
@echo RMAN fehlerhaft
:end
