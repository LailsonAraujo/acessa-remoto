<#
  Repara a abertura do Acessa Remoto pelo botão "Conectar" do painel.
  Não reinstala o aplicativo e não altera a senha de acesso permanente.
#>
$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
  exit
}

$exe = Join-Path $env:ProgramFiles "AcessaRemoto\AcessaRemoto.exe"
if (-not (Test-Path $exe)) {
  throw "Acessa Remoto não encontrado em: $exe. Execute primeiro o instalador completo."
}

function Register-UrlProtocol([string]$Scheme) {
  $root = "Registry::HKEY_CLASSES_ROOT\$Scheme"
  $command = "`"$exe`" `"%1`""

  New-Item -Path $root -Force | Out-Null
  Set-Item -Path $root -Value "URL:Acessa Remoto Protocol"
  New-ItemProperty -Path $root -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
  New-Item -Path "$root\DefaultIcon" -Force | Out-Null
  Set-Item -Path "$root\DefaultIcon" -Value "`"$exe`",0"
  New-Item -Path "$root\shell\open\command" -Force | Out-Null
  Set-Item -Path "$root\shell\open\command" -Value $command

  $saved = (Get-Item -Path "$root\shell\open\command").GetValue("")
  if ($saved -ne $command) {
    throw "Falha ao confirmar o protocolo $Scheme."
  }
}

Register-UrlProtocol -Scheme "acessaremoto"
Register-UrlProtocol -Scheme "rustdesk"

Write-Host "Protocolos do Acessa Remoto reparados e confirmados." -ForegroundColor Green
Write-Host "Feche e abra novamente o navegador antes de testar o botão Conectar."
Start-Sleep -Seconds 8
