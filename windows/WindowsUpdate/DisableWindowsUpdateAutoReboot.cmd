@ECHO OFF

SET HH=%TIME: =0%
SET HH=%HH:~0,2%

IF %HH% LSS 06 SET StartHour=12 & SET EndHour=07
IF %HH% GEQ 06 IF %HH% LSS 18 SET StartHour=06 & SET EndHour=13
IF %HH% GEQ 18 SET StartHour=12 & SET EndHour=07

CALL :ChangeActiveHours
REG IMPORT "%DynamicReg%"
EXIT

:ChangeActiveHours
SET DynamicReg=%temp%\ChangeActiveHours.reg
IF EXIST "%DynamicReg%" DEL /Q /F "%DynamicReg%"

ECHO Windows Registry Editor Version 5.00                              >>"%DynamicReg%"
ECHO.                                                                  >>"%DynamicReg%"
ECHO [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings] >>"%DynamicReg%"    
ECHO "ActiveHoursEnd"=dword:000000%EndHour%                            >>"%DynamicReg%"
ECHO "ActiveHoursStart"=dword:000000%StartHour%                        >>"%DynamicReg%"
ECHO "IsActiveHoursEnabled"=dword:00000001                             >>"%DynamicReg%"
GOTO :EOF
