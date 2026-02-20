# run_maestro.ps1
# Limpa ADB • garante 1 emulador (qazando) • seta ANDROID_SERIAL • roda o flow

param(
  [string]$AvdName = "qazando",
  [string]$FlowPath = ".\testerepetindo.yaml",
  [string]$MaestroLib = "C:\Users\User\maestro\lib",
  [int]$BootTimeoutSec = 120
)

$ErrorActionPreference = "Stop"

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$emulatorExe = Join-Path $env:LOCALAPPDATA "Android\Sdk\emulator\emulator.exe"

function Require-File($p, $label) {
  if (-not (Test-Path $p)) { throw "$label não encontrado: $p" }
}

function Get-Devices {
  & $adb devices | Select-Object -Skip 1 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and ($_ -notmatch "^\*") } |
    ForEach-Object {
      $parts = $_ -split "\s+"
      [pscustomobject]@{ Serial = $parts[0]; State = $parts[1] }
    }
}

function Wait-DeviceReady([string]$serial, [int]$timeoutSec) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    try {
      $boot = & $adb -s $serial shell getprop sys.boot_completed 2>$null
      if ($boot -match "1") { return $true }
    } catch {}
    Start-Sleep -Seconds 2
  }
  return $false
}

Require-File $adb "ADB"
Require-File $emulatorExe "Emulator"
Require-File $MaestroLib "Pasta lib do Maestro"
Require-File $FlowPath "Flow YAML"

Write-Host "==> 1) Limpando ADB..."
& $adb kill-server | Out-Null
Start-Sleep -Milliseconds 300
& $adb start-server | Out-Null

Write-Host "==> 2) Conferindo devices..."
$devices = Get-Devices

# Se tiver qualquer "offline", a gente zera o ADB e mata processos que normalmente ficam presos
if ($devices.State -contains "offline") {
  Write-Host "   Encontrado device OFFLINE. Limpando processos presos (emulator/qemu/adb)..."
  try { taskkill /IM emulator.exe /F | Out-Null } catch {}
  try { taskkill /IM qemu-system-x86_64.exe /F | Out-Null } catch {}
  try { taskkill /IM adb.exe /F | Out-Null } catch {}

  & $adb kill-server | Out-Null
  Start-Sleep -Milliseconds 300
  & $adb start-server | Out-Null
  $devices = Get-Devices
}

# Garantir 1 emulador
$online = $devices | Where-Object { $_.State -eq "device" }

if ($online.Count -eq 0) {
  Write-Host "==> 3) Nenhum emulador ativo. Iniciando AVD '$AvdName'..."
  Start-Process -FilePath $emulatorExe -ArgumentList "-avd", $AvdName | Out-Null
  Start-Sleep -Seconds 3

  # espera aparecer algum emulator-* device
  $deadline = (Get-Date).AddSeconds($BootTimeoutSec)
  do {
    Start-Sleep -Seconds 2
    $devices = Get-Devices
    $online = $devices | Where-Object { $_.State -eq "device" }
  } while ($online.Count -eq 0 -and (Get-Date) -lt $deadline)

  if ($online.Count -eq 0) {
    throw "Emulador não apareceu como 'device' no tempo limite. Rode 'adb devices' e verifique."
  }
}
elseif ($online.Count -gt 1) {
  throw "Há mais de 1 device conectado ($($online.Count)). Feche até ficar só 1 (ou ajuste o script para escolher)."
}

$serial = $online[0].Serial
Write-Host "==> 4) Device escolhido: $serial"

Write-Host "==> 5) Aguardando boot completo do Android..."
if (-not (Wait-DeviceReady -serial $serial -timeoutSec $BootTimeoutSec)) {
  throw "Android não ficou pronto (sys.boot_completed != 1) em $BootTimeoutSec s."
}

Write-Host "==> 6) Setando ANDROID_SERIAL e rodando Maestro..."
$env:ANDROID_SERIAL = $serial

# Executa Maestro via classpath (todas as libs)
java -cp "$MaestroLib\*" maestro.cli.AppKt test "$FlowPath"
