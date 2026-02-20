# start_studio.ps1
# Abre Maestro Studio automaticamente conectado ao emulator

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "Reiniciando ADB..."
& $adb kill-server
Start-Sleep -Milliseconds 300
& $adb start-server

Write-Host "Aguardando emulator ficar ONLINE..."

$serial = ""

while ($true) {
    $devices = & $adb devices

    if ($devices -match "emulator-\d+\s+device") {
        $serial = ($devices | Select-String "emulator-\d+\s+device").Matches.Value.Split()[0]
        break
    }

    Start-Sleep -Seconds 2
}

Write-Host "Emulator detectado: $serial"

$env:ANDROID_SERIAL = $serial

Write-Host "Abrindo Maestro Studio..."

java -cp "C:\Users\User\maestro\lib\*" maestro.cli.AppKt studio
