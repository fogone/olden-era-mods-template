# Builds the mods' packages and, with -Publish, releases them: a GitHub release per mod version with its zip, and the
# catalog (catalog\) updated, committed and pushed to main, where the mod manager reads it from.
#   .\release.ps1                          -> the packages of all mods (mods\*\bin\Release\net6.0\<id>-<version>.zip)
#   .\release.ps1 -Mods hello-button       -> one mod (its folder name)
#   .\release.ps1 -Install                 -> and the DLLs put into <game>\BepInEx\plugins to try them (the game closed)
#   .\release.ps1 -Publish                 -> and released (needs gh, logged in: gh auth login)
#   .\release.ps1 -Publish -CatalogName "My mods"   -> the catalog's name, needed the first time
# A version is released once: change a mod, raise its <Version> in its csproj, release again. A mod whose version is
# released already is skipped.
param([string[]]$Mods, [switch]$Publish, [switch]$Install, [string]$CatalogName, [string]$GameDir)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root
$gameArg = @()
if ($GameDir) { $gameArg = @("-p:GameDir=$GameDir") }

$folders = Get-ChildItem (Join-Path $root 'mods') -Directory | Where-Object { -not $Mods -or $Mods -contains $_.Name }
if (-not $folders) { throw "no mods: $($Mods -join ', ')" }

if ($Publish) {
    $repo = (gh repo view --json nameWithOwner -q .nameWithOwner)
    if ($LASTEXITCODE -ne 0 -or -not $repo) { throw "gh does not see the repository: push it to GitHub and run gh auth login" }
    if (git status --porcelain catalog) { throw "catalog\ has changes not committed: commit or drop them first" }
    dotnet tool restore | Out-Null
    $nameArg = @()
    if ($CatalogName) { $nameArg = @('--name', $CatalogName) }
}

foreach ($folder in $folders) {
    $project = (Get-ChildItem $folder.FullName -Filter *.csproj | Select-Object -First 1).FullName
    $id = (dotnet msbuild $project -nologo -getProperty:ModId).Trim()
    $version = (dotnet msbuild $project -nologo -getProperty:Version).Trim()
    dotnet build $project -c Release -t:ModPackage -nologo -v:minimal @gameArg | Select-Object -Last 2
    if ($LASTEXITCODE -ne 0) { throw "$($folder.Name) does not build" }
    $zip = Join-Path $folder.FullName "bin\Release\net6.0\$id-$version.zip"
    if (-not (Test-Path $zip)) { throw "no package $zip" }
    "$($folder.Name): $zip"
    if ($Install) {
        if (Get-Process HeroesOldenEra -ErrorAction SilentlyContinue) { throw "close the game first: a running game keeps its plugins" }
        $game = (dotnet msbuild $project -nologo -getProperty:GameDir @gameArg).Trim()
        $dll = (dotnet msbuild $project -nologo -getProperty:TargetFileName).Trim()
        Copy-Item (Join-Path $folder.FullName "bin\Release\net6.0\$dll") (Join-Path $game 'BepInEx\plugins') -Force
        "  installed into $game\BepInEx\plugins"
    }
    if (-not $Publish) { continue }

    $tag = "$id-v$version"
    $released = & { $ErrorActionPreference = 'Continue'; gh release view $tag *> $null; $LASTEXITCODE -eq 0 }
    if ($released) { "  $tag is released already: raise <Version> to release a change"; continue }
    gh release create $tag $zip --title "$id $version" --notes "$id $version for the Olden Era mod manager."
    if ($LASTEXITCODE -ne 0) { throw "gh release create $tag failed" }
    $url = "https://github.com/$repo/releases/download/$tag/$id-$version.zip"
    dotnet oe-catalog add --catalog catalog --root-url "https://raw.githubusercontent.com/$repo/main/catalog" `
        --package "$zip=$url" @nameArg
    if ($LASTEXITCODE -ne 0) { throw "oe-catalog add $id failed" }
    $nameArg = @()
}

if ($Publish -and (git status --porcelain catalog)) {
    git add catalog
    git commit -q -m "Catalog: $(($folders | ForEach-Object Name) -join ', ')"
    git push -q origin HEAD:main
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    "The catalog: https://raw.githubusercontent.com/$repo/main/catalog/catalog.json (add it in the game: Mods -> Sources)"
}
