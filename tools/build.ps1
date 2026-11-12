# Pyrelink: Moonlight for Android (GPL-3.0, github.com/moonlight-stream/moonlight-android),
# renamed and recoloured to go with Pyrelark, built with your Android Studio, installed on your phone.
#
#   Build Pyrelink.bat            build (downloads Moonlight's source the first time) and install
#   Build Pyrelink.bat -Update    start again from Moonlight's newest source
#   Build Pyrelink.bat -NoInstall build only
#   Build Pyrelink.bat -Bundle    also make Pyrelink.aab, the file Google Play takes (see play-kit\README.md)
#   Build Pyrelink.bat -MoonlightCommit <id>   build on that exact Moonlight version (see MOONLIGHT-COMMIT.txt)
#
# Every build writes the Moonlight version it used to MOONLIGHT-COMMIT.txt. "Publish source.bat" puts that and
# Pyrelink's changes on GitHub, which Moonlight's licence (GPL-3.0) requires for any copy you hand out.

param([switch]$Update, [switch]$NoInstall, [switch]$Bundle, [string]$MoonlightCommit)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
# Android's ndk-build can't cope with spaces in paths ("Godot Projects"), so the source lives in
# %LOCALAPPDATA%\Pyrelink\moonlight-src. The finished APK and build.log still land in this folder.
$work = Join-Path $env:LOCALAPPDATA 'Pyrelink'
if ($work -match ' ') { $work = 'C:\Pyrelink' }
# Before the rename the work folder was called EmberLink: move it rather than download everything again.
foreach ($oldWork in @((Join-Path $env:LOCALAPPDATA 'EmberLink'), 'C:\EmberLink')) {
    if ((Test-Path $oldWork) -and -not (Test-Path $work)) {
        try { Move-Item $oldWork $work -ErrorAction Stop; Write-Host "Moved $oldWork to $work (the Pyrewick rename)." }
        catch { Write-Host "Could not move $oldWork (something is using it); close Android Studio and try again." -ForegroundColor Yellow }
    }
}
$src = Join-Path $work 'moonlight-src'
New-Item -ItemType Directory -Force $work | Out-Null
$oldSrc = Join-Path $root 'moonlight-src'
if ((Test-Path (Join-Path $oldSrc 'app\build.gradle')) -and -not (Test-Path $src)) {
    Write-Host "Moving the downloaded source to $src (no spaces in the path)"
    try { Move-Item $oldSrc $src -ErrorAction Stop }
    catch { Write-Host 'Could not move it (a file is in use); a fresh copy will be downloaded instead.' -ForegroundColor Yellow }
    if (Test-Path $src) { foreach ($d in @('app\build', 'app\.cxx', 'build', '.gradle')) { $p = Join-Path $src $d; if (Test-Path $p) { Remove-Item $p -Recurse -Force } } }
} elseif (Test-Path $oldSrc) { Remove-Item $oldSrc -Recurse -Force }
$overlay = Join-Path $root 'overlay'
$utf8 = New-Object System.Text.UTF8Encoding $false

function Step([string]$t) { Write-Host ''; Write-Host "== $t" -ForegroundColor DarkYellow }
function Native([string]$exe, [string[]]$argv) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $exe @argv | Out-Host
    $code = $LASTEXITCODE; $ErrorActionPreference = $old
    return $code
}

# ------------------------------------------------------------------ tools
Step 'Checking tools'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is needed to download Moonlight''s source. Install Git for Windows from git-scm.com, then run this again.'
}
$studio = @("$env:ProgramFiles\Android\Android Studio", "${env:ProgramFiles(x86)}\Android\Android Studio", "$env:LOCALAPPDATA\Programs\Android Studio") |
    Where-Object { Test-Path (Join-Path $_ 'jbr\bin\java.exe') } | Select-Object -First 1
if (-not $studio) { throw 'Android Studio''s Java (the jbr folder) was not found.' }
$env:JAVA_HOME = Join-Path $studio 'jbr'
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if (-not (Test-Path $sdk)) { throw "The Android SDK wasn't found at $sdk." }
Write-Host "Java: $env:JAVA_HOME"
Write-Host "SDK:  $sdk"

# ------------------------------------------------------------------ source
if ($Update -and (Test-Path $src)) { Step 'Removing the old source'; Remove-Item $src -Recurse -Force }
if (-not (Test-Path (Join-Path $src 'app\build.gradle'))) {
    Step 'Downloading Moonlight for Android (source code, GPL-3.0)'
    if (Test-Path $src) { Remove-Item $src -Recurse -Force }
    $code = Native 'git' @('clone', '--depth', '1', '--recurse-submodules', '--shallow-submodules', 'https://github.com/moonlight-stream/moonlight-android.git', $src)
    if ($code -ne 0) { throw 'Downloading the source failed (git clone). Check the internet connection and run this again.' }
}

function GitOut([string[]]$argv) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = (& git @argv 2>$null | Out-String).Trim()
    $ErrorActionPreference = $old
    return $out
}
if ($MoonlightCommit) {
    $MoonlightCommit = $MoonlightCommit.Trim().ToLowerInvariant()
    if ($MoonlightCommit -notmatch '^[0-9a-f]{7,40}$') { throw "That doesn't look like a Moonlight commit id: $MoonlightCommit" }
    if (-not (GitOut @('-C', $src, 'rev-parse', 'HEAD')).StartsWith($MoonlightCommit)) {
        Step "Switching Moonlight's source to $MoonlightCommit"
        if ((Native 'git' @('-C', $src, 'fetch', '--depth', '1', 'origin', $MoonlightCommit)) -ne 0) { throw "Couldn't download Moonlight version $MoonlightCommit (use the full 40-character id)." }
        if ((Native 'git' @('-C', $src, 'checkout', '--force', 'FETCH_HEAD')) -ne 0) { throw 'Switching versions failed (git checkout).' }
        [void](Native 'git' @('-C', $src, 'clean', '-fdq', '-e', 'local.properties'))
        if ((Native 'git' @('-C', $src, 'submodule', 'update', '--init', '--recursive', '--force', '--depth', '1')) -ne 0) { throw 'Downloading Moonlight''s parts failed (git submodule update).' }
    }
}
$mlCommit = GitOut @('-C', $src, 'rev-parse', 'HEAD')
if ($mlCommit -match '^[0-9a-f]{40}$') {
    [IO.File]::WriteAllText((Join-Path $root 'MOONLIGHT-COMMIT.txt'), $mlCommit + "`r`n", $utf8)
    Write-Host "Moonlight version: $mlCommit"
}

# ------------------------------------------------------------------ make it Pyrelink
Step 'Making it Pyrelink'
$gradleFile = Join-Path $src 'app\build.gradle'
$g = [IO.File]::ReadAllText($gradleFile)
$g = $g -replace 'applicationId "com\.(limelight|ember\.link)"', 'applicationId "com.pyrewick.pyrelink"'
$g = $g -replace 'applicationIdSuffix "\.unofficial"', 'applicationIdSuffix ""'
$g = $g -replace '"app_label", "(Moonlight|Ember Link) \(Debug\)"', '"app_label", "Pyrelink (Debug)"'
$g = $g -replace '"app_label", "(Moonlight|Ember Link)"', '"app_label", "Pyrelink"'
$g = $g.Replace('// Ember Link: release key', '// Pyrelink: release key').Replace('EmberStudio/signing', 'Pyrewick/signing')
# (Older builds were signed with Android Studio's debug key; the release key below now replaces it.)
if ($g -notmatch 'signingConfig signingConfigs\.debug') {
    $g = $g -replace 'minifyEnabled true', "minifyEnabled true`r`n            signingConfig signingConfigs.debug"
}
# Release key: Pyrelink's own signing key, made once and kept outside the project in
# %APPDATA%\Pyrewick\signing. Every build from now on is signed with it, which Google Play and safe
# updates need. Lose it and phones can't update Pyrelink any more, so back that folder up.
$keyDir = Join-Path $env:APPDATA 'Pyrewick\signing'
$oldStudio = Join-Path $env:APPDATA 'EmberStudio'; $newStudio = Join-Path $env:APPDATA 'Pyrewick'
if ((Test-Path $oldStudio) -and -not (Test-Path $newStudio)) { Move-Item $oldStudio $newStudio; Write-Host "Moved $oldStudio to $newStudio (the Pyrewick rename)." }
$keyFile = Join-Path $keyDir 'ember-link-release.jks'
$keyProps = Join-Path $keyDir 'ember-link-release.properties'
# The key file's own path is written inside the .properties file: keep it pointing at where the key is now.
if ((Test-Path $keyFile) -and (Test-Path $keyProps)) {
    $pt = [IO.File]::ReadAllText($keyProps)
    $want = 'storeFile=' + ($keyFile -replace '\\', '/')
    $pt2 = [regex]::Replace($pt, '(?m)^storeFile=.*$', $want.Replace('$', '$$'))
    if ($pt2 -ne $pt) { [IO.File]::WriteAllText($keyProps, $pt2, $utf8) }
}
if (-not (Test-Path $keyFile)) {
    Step 'Making Pyrelink''s release key (once)'
    New-Item -ItemType Directory -Force $keyDir | Out-Null
    $bytes = New-Object byte[] 24; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $pass = ([Convert]::ToBase64String($bytes) -replace '[+/=]', 'x')
    $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
    $code = Native $keytool @('-genkeypair', '-keystore', $keyFile, '-storetype', 'PKCS12', '-alias', 'emberlink', '-keyalg', 'RSA', '-keysize', '4096', '-validity', '10000', '-storepass', $pass, '-keypass', $pass, '-dname', 'CN=Pyrelink, O=Ember')
    if ($code -ne 0 -or -not (Test-Path $keyFile)) { throw 'Making the release key failed (keytool).' }
    [IO.File]::WriteAllText($keyProps, "storeFile=$($keyFile -replace '\\', '/')`r`nstorePassword=$pass`r`nkeyAlias=emberlink`r`nkeyPassword=$pass`r`n", $utf8)
    Write-Host ''
    Write-Host '  Pyrelink now has its own release key:' -ForegroundColor Green
    Write-Host "    $keyDir" -ForegroundColor Green
    Write-Host '  BACK UP THAT FOLDER (a USB stick or a password manager). Without it, phones can''t update Pyrelink.' -ForegroundColor Yellow
}
if ($g -notmatch '// Pyrelink: release key') {
    $propsPath = $keyProps -replace '\\', '/'
    $g += @"

// Pyrelink: release key (the passwords stay in $propsPath, not in this file)
android {
    signingConfigs {
        ember {
            def p = new Properties()
            file('$propsPath').withInputStream { p.load(it) }
            storeFile file(p['storeFile'])
            storePassword p['storePassword']
            keyAlias p['keyAlias']
            keyPassword p['keyPassword']
        }
    }
    buildTypes { release { signingConfig signingConfigs.ember } }
}
"@
}
[IO.File]::WriteAllText($gradleFile, $g, $utf8)
if ($g -notmatch 'com\.pyrewick\.pyrelink' -or $g -notmatch '"Pyrelink"') {
    throw 'Could not rename the app in app\build.gradle (Moonlight changed that file). Send this message to Claude.'
}
Write-Host 'Name: Pyrelink   App ID: com.pyrewick.pyrelink'

# The rename: words written by earlier builds ("Ember Link", "Ember Hall") become Pyrelink and Pyrelark.
# Runs before the patches below, which use the new words too.
Get-ChildItem (Join-Path $src 'app\src\main') -Recurse -File -Include *.java, *.xml | ForEach-Object {
    $t = [IO.File]::ReadAllText($_.FullName)
    if ($t.Contains('Ember Link') -or $t.Contains('Ember Hall') -or $t.Contains('EMBER LINK')) { [IO.File]::WriteAllText($_.FullName, $t.Replace('Ember Link', 'Pyrelink').Replace('Ember Hall', 'Pyrelark').Replace('EMBER LINK', 'PYRELINK'), $utf8) }
}

# Words on screen: "Moonlight" becomes "Pyrelink" (links such as moonlight-stream.org are left alone).
$res = Join-Path $src 'app\src\main\res'
$strings = Join-Path $res 'values\strings.xml'
if (Test-Path $strings) {
    $s = [IO.File]::ReadAllText($strings)
    $s = [regex]::Replace($s, '(?<![\w./-])Moonlight(?![\w./-])', 'Pyrelink')
    [IO.File]::WriteAllText($strings, $s, $utf8)
}

# Icon and colours.
Get-ChildItem $overlay -Recurse -File | ForEach-Object {
    $dest = Join-Path $res $_.FullName.Substring($overlay.Length + 1)
    New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
    Copy-Item $_.FullName $dest -Force
}
$colors = @{
    'android:colorAccent' = '#FF8A3D'; 'android:colorPrimary' = '#1A1517'; 'android:colorPrimaryDark' = '#0E0C0D'
    'android:colorControlActivated' = '#FF8A3D'; 'android:statusBarColor' = '#0E0C0D'; 'android:navigationBarColor' = '#0E0C0D'
}
$darkOnly = @{ 'android:windowBackground' = '#0E0C0D'; 'android:colorBackground' = '#0E0C0D' }
$themed = 0
Get-ChildItem $res -Directory -Filter 'values*' | ForEach-Object {
    Get-ChildItem $_.FullName -Filter '*.xml' | ForEach-Object {
        $file = $_.FullName
        $raw = [IO.File]::ReadAllText($file)
        if ($raw -notmatch 'name="AppTheme"') { return }
        $x = New-Object System.Xml.XmlDocument
        $x.PreserveWhitespace = $true
        $x.LoadXml($raw)
        $st = $x.SelectSingleNode("//style[@name='AppTheme']")
        if (-not $st) { return }
        $set = $colors.Clone()
        # Only darken the background if the theme is already a dark one, so text stays readable.
        if ($st.GetAttribute('parent') -notmatch 'Light') { foreach ($k in $darkOnly.Keys) { $set[$k] = $darkOnly[$k] } }
        foreach ($k in $set.Keys) {
            $it = $st.SelectSingleNode("item[@name='$k']")
            if (-not $it) { $it = $x.CreateElement('item'); $it.SetAttribute('name', $k); [void]$st.AppendChild($it) }
            $it.InnerText = $set[$k]
        }
        $ws = New-Object System.Xml.XmlWriterSettings
        $ws.Encoding = $utf8
        $w = [System.Xml.XmlWriter]::Create($file, $ws)
        $x.Save($w); $w.Close()
        $themed++
        Write-Host ('Coloured ' + $_.Directory.Name + '\' + $_.Name)
    }
}
if ($themed -eq 0) { Write-Host 'Note: no AppTheme found to recolour; the build continues with Moonlight''s colours.' -ForegroundColor Yellow }

# Pyrelink's own code (the Pyrewick boot screen and sign-in) goes in next to Moonlight's.
$javaSrc = Join-Path $root 'java'
$javaDst = Join-Path $src 'app\src\main\java'
if (Test-Path $javaSrc) {
    Get-ChildItem $javaSrc -Recurse -File -Filter '*.java' | ForEach-Object {
        $dest = Join-Path $javaDst $_.FullName.Substring($javaSrc.Length + 1)
        New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
        Copy-Item $_.FullName $dest -Force
    }
}
# The address of Pyrelark's server, from "Deploy server.bat"'s settings.
$serverUrl = 'https://api.pyrelark.com'
$serverJson = Join-Path $env:APPDATA 'Pyrewick\server.json'
if (Test-Path $serverJson) { try { $sj = Get-Content $serverJson -Raw | ConvertFrom-Json; if ($sj.url) { $serverUrl = [string]$sj.url } } catch { } }
$cfgDir = Join-Path $javaDst 'com\limelight\pyrewick'
New-Item -ItemType Directory -Force $cfgDir | Out-Null
[IO.File]::WriteAllText((Join-Path $cfgDir 'PyrewickConfig.java'), "package com.limelight.pyrewick;`r`n`r`n// Made by tools\build.ps1.`r`npublic final class PyrewickConfig {`r`n    public static final String SERVER_URL = `"$serverUrl`";`r`n}`r`n", $utf8)
Write-Host "Pyrelark's server: $serverUrl"

# Pyrelink's behaviour: open straight into Pyrelark, DeX full screen, hide Sunshine's extras, headings.
. (Join-Path $PSScriptRoot 'patches.ps1')
foreach ($p in $Patches) {
    $file = Join-Path $src $p.File
    if (-not (Test-Path $file)) { throw "Pyrelink change can't find $($p.File). Moonlight's code has moved; send this message to Claude." }
    $text = [IO.File]::ReadAllText($file)
    if ($text.Contains($p.Marker)) { continue }
    $find = $p.Find -replace "`r`n", "`n"; $rep = $p.Replace -replace "`r`n", "`n"
    if ($text.Contains("`r`n")) { $find = $find -replace "`n", "`r`n"; $rep = $rep -replace "`n", "`r`n" }
    $at = $text.IndexOf($find)
    if ($at -lt 0) { throw "Pyrelink change for $($p.File) (" + $p.Marker + ") no longer fits Moonlight's code. Send this message to Claude." }
    $text = $text.Substring(0, $at) + $rep + $text.Substring($at + $find.Length)
    [IO.File]::WriteAllText($file, $text, $utf8)
    Write-Host ('Changed ' + (Split-Path -Leaf $p.File) + ': ' + $p.Marker)
}

# A flat copy of the on-screen controller code, so Claude can read it for the forge touch controls.
$peek = Join-Path $src 'ember-peek'
New-Item -ItemType Directory -Force $peek | Out-Null
$vc = Join-Path $src 'app\src\main\java\com\limelight\binding\input\virtual_controller'
if (Test-Path $vc) { Get-ChildItem $vc -Recurse -Filter '*.java' | ForEach-Object { Copy-Item $_.FullName (Join-Path $peek $_.Name) -Force } }
foreach ($f in @('app\src\main\java\com\limelight\preferences\PreferenceConfiguration.java', 'app\src\main\java\com\limelight\Game.java',
                 'app\src\main\java\com\limelight\nvstream\http\ComputerDetails.java', 'app\src\main\java\com\limelight\utils\ServerHelper.java',
                 'app\src\main\java\com\limelight\preferences\WebLauncherPreference.java')) {
    $fp = Join-Path $src $f; if (Test-Path $fp) { Copy-Item $fp (Join-Path $peek (Split-Path -Leaf $fp)) -Force }
}

# ------------------------------------------------------------------ build
Step 'Building (the first build downloads the NDK and SDK parts it needs and can take 10-20 minutes)'
[IO.File]::WriteAllText((Join-Path $src 'local.properties'), 'sdk.dir=' + ($sdk -replace '\\', '\\') + "`r`n", $utf8)
$log = Join-Path $root 'build.log'
if (Test-Path $log) { Remove-Item $log -Force }
Push-Location $src
$old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
try {
    # Everything Gradle prints also goes to pyrelink\build.log, so the whole error can be read later.
    $tasks = @('assembleNonRootRelease'); if ($Bundle) { $tasks += 'bundleNonRootRelease' }
    & (Join-Path $src 'gradlew.bat') @tasks 2>&1 | ForEach-Object {
        $line = "$_"
        Add-Content -Path $log -Value $line -Encoding UTF8
        $line
    } | Out-Host
    $code = $LASTEXITCODE
} finally { $ErrorActionPreference = $old; Pop-Location }
if ($code -ne 0) {
    Write-Host ''
    Write-Host '---------------- what went wrong ----------------' -ForegroundColor Yellow
    $hits = Select-String -Path $log -Pattern 'What went wrong|error:|FAILURE:|Failed to|not accepted|> Could not' -SimpleMatch:$false
    if ($hits) { $hits | Select-Object -First 25 | ForEach-Object { Write-Host $_.Line -ForegroundColor Yellow } }
    $wrong = Select-String -Path $log -Pattern 'What went wrong' -Context 0, 14 | Select-Object -First 1
    if ($wrong) { $wrong.Context.PostContext | ForEach-Object { Write-Host $_ -ForegroundColor Yellow } }
    throw 'The build failed. The full log is in pyrelink\build.log; tell Claude and it can read it.'
}
$apk = Get-ChildItem (Join-Path $src 'app\build\outputs\apk') -Recurse -Filter '*.apk' |
    Where-Object { $_.FullName -match 'nonRoot' -and $_.FullName -match 'release' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $apk) { throw 'The build finished but no APK was found under app\build\outputs\apk.' }
$out = Join-Path $root 'Pyrelink.apk'
Copy-Item $apk.FullName $out -Force
Write-Host ("Built Pyrelink.apk ({0:N0} MB)" -f ($apk.Length / 1MB)) -ForegroundColor Green
if ($Bundle) {
    $aab = Get-ChildItem (Join-Path $src 'app\build\outputs\bundle') -Recurse -Filter '*.aab' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'nonRoot' -and $_.FullName -match 'elease' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($aab) { Copy-Item $aab.FullName (Join-Path $root 'Pyrelink.aab') -Force; Write-Host ("Built Pyrelink.aab ({0:N0} MB) for Google Play" -f ($aab.Length / 1MB)) -ForegroundColor Green }
    else { Write-Host 'No .aab was made; check build.log.' -ForegroundColor Yellow }
}

# ------------------------------------------------------------------ install
if ($NoInstall) { return }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) { Write-Host 'adb not found; copy Pyrelink.apk to the phone to install it.' -ForegroundColor Yellow; return }
Step 'Installing on your phone'
$devices = (& $adb devices) | Select-String -Pattern "`tdevice$"
if (-not $devices) {
    Write-Host 'No phone is connected. Plug it in with USB debugging on, or pair over Wi-Fi with ember-launcher\pair_phone.bat, then run this again. The second build is quick.' -ForegroundColor Yellow
    return
}
$old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
$said = (& $adb install -r $out 2>&1 | Out-String); $code = $LASTEXITCODE
$ErrorActionPreference = $old
Write-Host $said.Trim()
if ($code -ne 0 -and $said -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
    # The copy on the phone was signed with the old test key; Android won't swap keys over an install.
    Write-Host ''
    Write-Host 'The Pyrelink on your phone was signed with the old test key, so it has to be removed once' -ForegroundColor Yellow
    Write-Host 'before the properly signed one can go on. Your paired PCs and touch layouts will need setting up again.' -ForegroundColor Yellow
    $yes = Read-Host 'Remove the old Pyrelink and install the new one? (y/n)'
    if ($yes -notmatch '^[yY]') { Write-Host 'Left the old one in place. Pyrelink.apk is ready whenever you want to switch.'; return }
    [void](Native $adb @('uninstall', 'com.pyrewick.pyrelink'))
    $code = Native $adb @('install', $out)
}
if ($code -ne 0) { throw 'Installing failed. If the phone asked to allow the install, allow it and run this again.' }
[void](Native $adb @('shell', 'monkey', '-p', 'com.pyrewick.pyrelink', '-c', 'android.intent.category.LAUNCHER', '1'))
# The app from before the rename (Ember Link) is a separate app on the phone; offer to remove it.
$old = (& $adb shell pm list packages com.ember.link 2>$null | Out-String)
if ($old -match 'package:com\.ember\.link') {
    Write-Host ''
    Write-Host 'The old Ember Link is still on your phone. Pyrelink replaces it (pair it with your PC once, the same way).' -ForegroundColor Yellow
    if ((Read-Host 'Remove the old Ember Link now? (y/n)') -match '^[yY]') { [void](Native $adb @('uninstall', 'com.ember.link')); Write-Host 'Removed.' -ForegroundColor Green }
}
Write-Host 'Pyrelink is installed and open on your phone.' -ForegroundColor Green
