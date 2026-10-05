Unicode true

!ifndef SOURCE_DIR
  !error "SOURCE_DIR is required"
!endif
!ifndef OUT_FILE
  !error "OUT_FILE is required"
!endif
!ifndef ICON_FILE
  !error "ICON_FILE is required"
!endif
!ifndef APP_VERSION
  !define APP_VERSION "0.0.0"
!endif

Name "Rantlist"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Rantlist"
InstallDirRegKey HKCU "Software\Rantlist" "InstallDir"
RequestExecutionLevel user
Icon "${ICON_FILE}"
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "Rantlist"
VIAddVersionKey "FileDescription" "Rantlist desktop client installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Rantlist" SEC_MAIN
  SetOutPath "$INSTDIR"
  File /r "${SOURCE_DIR}/*"
  WriteRegStr HKCU "Software\Rantlist" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall Rantlist.exe"
  CreateDirectory "$SMPROGRAMS\Rantlist"
  CreateShortcut "$SMPROGRAMS\Rantlist\Rantlist.lnk" "$INSTDIR\Rantlist.exe"
  CreateShortcut "$DESKTOP\Rantlist.lnk" "$INSTDIR\Rantlist.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Rantlist.lnk"
  Delete "$SMPROGRAMS\Rantlist\Rantlist.lnk"
  RMDir "$SMPROGRAMS\Rantlist"
  DeleteRegKey HKCU "Software\Rantlist"
  RMDir /r "$INSTDIR"
SectionEnd
