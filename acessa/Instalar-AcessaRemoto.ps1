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
Start-Process -FilePath $Instalador -ArgumentList "--silent-install" -Wait

$exe = Join-Path $env:ProgramFiles "AcessaRemoto\AcessaRemoto.exe"
for ($i = 0; $i -lt 60 -and -not (Test-Path $exe); $i++) { Start-Sleep -Seconds 2 }
if (-not (Test-Path $exe)) { throw "Instalação não concluída: $exe não encontrado. Envie os logs de $env:APPDATA\AcessaRemoto\log e C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\AcessaRemoto\log" }

# Serviço com início automático (funciona na tela de login e com UAC)
$svc = Get-Service -Name "AcessaRemoto" -ErrorAction SilentlyContinue
if ($svc) { Set-Service -Name "AcessaRemoto" -StartupType Automatic; if ($svc.Status -ne "Running") { Start-Service "AcessaRemoto" } }
Start-Sleep -Seconds 5

$r = & $exe --password $Senha | Out-String
if ($r -notmatch "Done") { Start-Sleep -Seconds 5; $r = & $exe --password $Senha | Out-String }
if ($r -notmatch "Done") { throw "Falha ao definir a senha: $r" }

$id = ""
for ($i = 0; $i -lt 15 -and [string]::IsNullOrWhiteSpace($id); $i++) { $id = (& $exe --get-id | Out-String).Trim(); if (-not $id) { Start-Sleep 2 } }

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
Read-Host "Pressione ENTER para fechar"
