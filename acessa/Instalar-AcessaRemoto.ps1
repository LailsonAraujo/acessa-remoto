<#
  Acessa Remoto - instalação e configuração de acesso não assistido.
  Uso (PowerShell como Administrador, na mesma pasta do AcessaRemoto-setup.exe):
     .\Instalar-AcessaRemoto.ps1                 # gera uma senha aleatória para esta máquina
     .\Instalar-AcessaRemoto.ps1 -Senha "Xyz..."   # define a senha informada
#>
param(
  [string]$Senha = "",
  [string]$Instalador = "$PSScriptRoot\AcessaRemoto-setup.exe"
)
$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Senha `"$Senha`" -Instalador `"$Instalador`""
  exit
}

if (-not (Test-Path $Instalador)) { throw "Instalador não encontrado: $Instalador" }

if ([string]::IsNullOrWhiteSpace($Senha)) {
  $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789".ToCharArray()
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $bytes = New-Object byte[] 12; $rng.GetBytes($bytes)
  $Senha = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}
if ($Senha.Length -lt 8) { throw "A senha deve ter pelo menos 8 caracteres." }

Write-Host "Instalando Acessa Remoto..." -ForegroundColor Cyan
# -Wait esperaria também o serviço/bandeja abertos pelo instalador (nunca terminam); espera só o processo do instalador
$proc = Start-Process -FilePath $Instalador -ArgumentList "--silent-install" -PassThru
$null = $proc.WaitForExit(180000)

$dirApp = Join-Path $env:ProgramFiles "AcessaRemoto"
$exe = Join-Path $dirApp "AcessaRemoto.exe"
$orig = Join-Path $dirApp "rustdesk.exe"
for ($i = 0; $i -lt 60 -and -not (Test-Path $exe) -and -not (Test-Path $orig); $i++) { Start-Sleep -Seconds 2 }

# O executável vem como rustdesk.exe; serviço, atalhos e registro esperam AcessaRemoto.exe
if (-not (Test-Path $exe) -and (Test-Path $orig)) {
  Write-Host "Ajustando nome do executável..." -ForegroundColor Cyan
  Stop-Service -Name "AcessaRemoto" -Force -ErrorAction SilentlyContinue
  Get-Process -Name "rustdesk", "AcessaRemoto" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  for ($i = 0; $i -lt 10 -and -not (Test-Path $exe); $i++) {
    try { Rename-Item -Path $orig -NewName "AcessaRemoto.exe" -ErrorAction Stop }
    catch { Get-Process -Name "rustdesk" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
  }
  Start-Service -Name "AcessaRemoto" -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 5
}
if (-not (Test-Path $exe)) { throw "Instalação não concluída: $exe não encontrado. Envie os logs de $env:APPDATA\AcessaRemoto\log e C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\AcessaRemoto\log" }


function Invoke-Acessa([string[]]$Argumentos, [int]$Segundos = 30) {
  $out = [System.IO.Path]::GetTempFileName()
  $p = Start-Process -FilePath $exe -ArgumentList $Argumentos -NoNewWindow -PassThru -RedirectStandardOutput $out
  if (-not $p.WaitForExit($Segundos * 1000)) { try { $p.Kill() } catch {} }
  $txt = Get-Content $out -Raw -ErrorAction SilentlyContinue; Remove-Item $out -ErrorAction SilentlyContinue
  if ($null -eq $txt) { "" } else { $txt }
}
# Serviço com início automático (funciona na tela de login e com UAC)
$svc = Get-Service -Name "AcessaRemoto" -ErrorAction SilentlyContinue
if ($svc) { Set-Service -Name "AcessaRemoto" -StartupType Automatic; if ($svc.Status -ne "Running") { Start-Service "AcessaRemoto" } }
Start-Sleep -Seconds 5

$r = Invoke-Acessa @("--password", "`"$Senha`"")
if ($r -notmatch "Done") { Start-Sleep -Seconds 5; $r = Invoke-Acessa @("--password", "`"$Senha`"") }
if ($r -notmatch "Done") { throw "Falha ao definir a senha: $r" }

$id = ""
for ($i = 0; $i -lt 15 -and [string]::IsNullOrWhiteSpace($id); $i++) { $id = (Invoke-Acessa @("--get-id")).Trim(); if (-not $id) { Start-Sleep 2 } }

$dir = Join-Path $env:ProgramData "AcessaRemoto"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$file = Join-Path $dir "acesso.txt"
"Computador: $env:COMPUTERNAME`r`nID: $id`r`nSenha: $Senha`r`nData: $(Get-Date -Format 'dd/MM/yyyy HH:mm')" | Set-Content -Path $file -Encoding UTF8
icacls $dir /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" | Out-Null

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Acessa Remoto instalado" -ForegroundColor Green
Write-Host " Computador : $env:COMPUTERNAME"
Write-Host " ID         : $id"
Write-Host " Senha      : $Senha"
Write-Host " Cópia salva em $file (somente administradores)"
Write-Host "==============================================" -ForegroundColor Green
Write-Host "Cadastre este ID no painel: https://remoto.sextafeira.ia.br/_admin/"
Start-Process -FilePath $exe -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Esta janela fecha sozinha em 60 segundos (ou pressione qualquer tecla)." -ForegroundColor Yellow
$fim = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $fim) {
  if ([Console]::KeyAvailable) { $null = [Console]::ReadKey($true); break }
  Start-Sleep -Milliseconds 250
}
exit 0
