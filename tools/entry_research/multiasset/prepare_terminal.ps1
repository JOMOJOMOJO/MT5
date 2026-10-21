param([string]$Destination="$env:LOCALAPPDATA\CodexMT5Multiasset20261016")
$ErrorActionPreference='Stop'
$base='C:\Program Files\XMTrading MT5'
$source="$env:APPDATA\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675"
if(Test-Path -LiteralPath $Destination){ throw 'Destination exists; refusing to overwrite' }
New-Item -ItemType Directory -Path $Destination | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Destination 'config') | Out-Null
foreach($name in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')){
 Copy-Item -LiteralPath (Join-Path $base $name) -Destination $Destination
}
# Cached authentication remains machine-local; never copied into the repository.
foreach($name in @('accounts.dat','servers.dat','common.ini')){
 Copy-Item -LiteralPath (Join-Path $source "config\$name") -Destination (Join-Path $Destination 'config')
}
$ini=Join-Path $Destination 'config\common.ini'
$lines=Get-Content -LiteralPath $ini
$new=[System.Collections.Generic.List[string]]::new()
$section=''
foreach($line in $lines){
 if($line -match '^\[(.+)\]'){ $section=$matches[1] }
 if($section -eq 'Experts'){ continue }
 $new.Add($line)
}
$new.Add('[Experts]'); $new.Add('Enabled=0'); $new.Add('AllowLiveTrading=0'); $new.Add('AllowDllImport=0')
Set-Content -LiteralPath $ini -Value $new -Encoding Unicode
$startup=Join-Path $Destination 'research.ini'
@'
[Charts]
MaxBars=2000000
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
'@ | Set-Content -LiteralPath $startup -Encoding ASCII
$process=Start-Process -FilePath (Join-Path $Destination 'terminal64.exe') -ArgumentList @('/portable',"/config:$startup") -WindowStyle Hidden -PassThru
[PSCustomObject]@{Terminal=(Join-Path $Destination 'terminal64.exe');PID=$process.Id}
