param(
  [string]$Protoc = 'protoc',
  [string]$Dart = 'dart'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageConfig = Join-Path $projectRoot '.dart_tool/package_config.json'
if (-not (Test-Path -LiteralPath $packageConfig)) { throw 'Run flutter pub get before generating protobuf bindings.' }
$config = Get-Content -LiteralPath $packageConfig -Raw | ConvertFrom-Json
$plugin = $config.packages | Where-Object name -eq 'protoc_plugin'
if (-not $plugin) { throw 'protoc_plugin is missing from package_config.json.' }
$baseUri = [Uri]::new($packageConfig)
$pluginUri = [Uri]::new($baseUri, $plugin.rootUri)
$pluginSource = Join-Path $pluginUri.LocalPath 'bin/protoc_plugin.dart'
$toolDirectory = Join-Path $projectRoot '.dart_tool/codegen'
[IO.Directory]::CreateDirectory($toolDirectory) | Out-Null
$pluginExecutable = Join-Path $toolDirectory 'protoc-gen-dart.exe'
Push-Location $projectRoot
try {
  & $Dart compile exe "--packages=$packageConfig" $pluginSource -o $pluginExecutable
  if ($LASTEXITCODE -ne 0) { throw 'Dart protobuf plugin compilation failed.' }
  $protoRoot = Join-Path $projectRoot 'proto'
  $outputRoot = Join-Path $projectRoot 'lib/core/proto'
  [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
  $files = Get-ChildItem -LiteralPath $protoRoot -Recurse -Filter '*.proto' | ForEach-Object { [IO.Path]::GetRelativePath($protoRoot, $_.FullName).Replace('\', '/') }
  & $Protoc "--proto_path=$protoRoot" "--dart_out=$outputRoot" "--plugin=protoc-gen-dart=$pluginExecutable" @files
  if ($LASTEXITCODE -ne 0) { throw 'Protobuf schema compilation failed.' }
  Write-Output "Generated Dart bindings for $($files.Count) upstream schema files."
} finally { Pop-Location }
