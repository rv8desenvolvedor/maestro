# start_emulator.ps1
# Inicia o AVD qazando

$emulator = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"

Write-Host "Iniciando emulador qazando..."

Start-Process -FilePath $emulator -ArgumentList "-avd", "qazando"
