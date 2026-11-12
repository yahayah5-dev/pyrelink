# Pyrelink

Pyrelink streams the games on your Windows PC to your Android phone, tablet or TV. It's the streaming half of
[Pyrelark](https://pyrelark.com), the game launcher from Pyrewick.

Pyrelink is a modified version of **[Moonlight for Android](https://github.com/moonlight-stream/moonlight-android)**,
the open-source game streaming client, and is released under the same licence, the
**GNU General Public License v3.0** (see [LICENSE.txt](LICENSE.txt)). Pyrelink is not made or endorsed by the
Moonlight team. Thank you to them for Moonlight.

## What's here

This repository holds Pyrelink's changes, applied on top of Moonlight's own source when Pyrelink is built:

| Path | What it is |
|---|---|
| `tools/build.ps1` | Downloads Moonlight's source, applies Pyrelink's changes, builds and signs the app |
| `tools/patches.ps1` | Pyrelink's changes to Moonlight's code |
| `java/` | Pyrelink's own code (the Pyrelark account, the sign-in screen and Friends) |
| `overlay/` | Pyrelink's icon, colours and layout values |
| `MOONLIGHT-COMMIT.txt` | The exact Moonlight version this release was built on |

This release is built on Moonlight commit
[`b48494cb96bf`](https://github.com/moonlight-stream/moonlight-android/tree/b48494cb96bff23d8886c4775cc4f39a1075495d).

## What Pyrelink changes

- Opens straight into Pyrelark's big-screen library when your PC is online, and leaves your PC as it was when
  you stop streaming.
- Sign-in with a Pyrelark account (the same one as on the PC and at pyrelark.com), including account deletion.
- Friends: who's online and what they're playing, friend requests and codes, and friends' profiles.
- Pyrelink's name, app ID (`com.pyrewick.pyrelink`), icon and colours; larger game covers; Samsung DeX full screen.

## Building it yourself

You need Windows, [Git for Windows](https://git-scm.com) and [Android Studio](https://developer.android.com/studio)
(for its Java and Android SDK).

1. Download this repository.
2. Double-click **Build Pyrelink.bat**. Or, to build on exactly the Moonlight version of this release:

   ```
   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -MoonlightCommit b48494cb96bff23d8886c4775cc4f39a1075495d -NoInstall
   ```

The first build downloads Moonlight's source and the Android parts it needs (about 1.5 GB) into
`%LOCALAPPDATA%\Pyrelink`. The finished `Pyrelink.apk` appears next to the .bat.

- **Signing:** the first build makes a new signing key in `%APPDATA%\Pyrewick\signing`. Your build is signed with
  your key, so Android won't install it over the official Pyrelink (or the other way round): uninstall one first.
- **Server:** the app signs in to `https://api.pyrelark.com`. To point a build at a different server, put
  `{"url": "https://your-server"}` in `%APPDATA%\Pyrewick\server.json`.

## Names and logos

The licence covers the code. The names Pyrelink, Pyrelark and Pyrewick and their logos aren't licensed for use
as branding (GPL-3.0 section 7(e)): if you share a modified version, give it your own name and icon.

## Contact

support@pyrewick.com · [https://github.com/yahayah5-dev/pyrelink](https://github.com/yahayah5-dev/pyrelink)
