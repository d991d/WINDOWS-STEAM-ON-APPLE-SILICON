# Windows Steam on Apple Silicon

Getting the Windows Steam client and a Direct3D 12 game running on an M-series Mac with
[Whisky](https://github.com/frankea/Whisky) — including the two failures that cost me an
evening: a bottle that vanished, and audio that was silently muted by a USB headset.

| | |
|---|---|
| **Machine** | Mac mini M4 |
| **macOS** | 26.6.2 |
| **Whisky** | 3.7.0 (frankea fork) |
| **Game** | Commandos: Origins |
| **Result** | Playable |

A rendered version of this guide is at
**[YOUR-USERNAME.github.io/whisky-steam-apple-silicon](https://YOUR-USERNAME.github.io/whisky-steam-apple-silicon/)**.

---

## Contents

1. [Before you start](#before-you-start)
2. [Install the right Whisky](#1-install-the-right-whisky)
3. [Pin the version](#2-pin-the-version)
4. [Create the bottle](#3-create-the-bottle)
5. [Settings for the Steam client](#4-settings-for-the-steam-client)
6. [Install Steam](#5-install-steam)
7. [Reuse an existing library](#6-reuse-an-existing-library)
8. [Graphics for the game](#7-graphics-for-the-game)
9. [Fix the audio](#8-fix-the-audio)
10. [Troubleshooting](#troubleshooting)
11. [Recovering a lost bottle](#recovering-a-lost-bottle)

---

## Before you start

Three things decide whether this is worth your evening.

**Check the game first.** Look it up on [ProtonDB](https://www.protondb.com/). Gold or Platinum
means it runs well under Wine; anything with EasyAntiCheat or BattlEye will not run at all, on any
Wine-based route, and no configuration changes that. Commandos: Origins is rated Platinum, which is
why it was a reasonable target.

**The original Whisky is dead.** Isaac Marovitz ended development in April 2025 and pointed users at
CrossOver. What is still maintained is the community fork at
[frankea/Whisky](https://github.com/frankea/Whisky), which is what this guide uses. The plain
`brew install --cask whisky` still installs the archived original — don't use it.

**This road has an expiry date.** Apple has said macOS 27 is the last release with Rosetta, after
which only a narrow set of legacy game frameworks keeps working. The x86 Wine-under-Rosetta approach
ends there. Native ARM64 work is underway — CodeWeavers has a CrossOver preview built on it — but it
is not finished. Set your expectations accordingly.

> **Cost of the free route**
> CrossOver is the paid, maintained version of the same underlying technology, and its developers do
> the Wine work everyone else benefits from. If this setup becomes something you use regularly,
> buying it is the honest move.

---

## 1. Install the right Whisky

```bash
brew install --cask frankea/whisky/whisky
```

Install it to `/Applications`. Do not keep the app on an external drive: if the volume is unmounted,
renamed, or swept by a sync client, the app disappears mid-session and every bottle it manages
appears broken. The app is 22 MB. Your bottles and games are the large things, and they can live
elsewhere.

---

## 2. Pin the version

Whisky ships updates through Sparkle, and an update can break a working setup — 3.7.0 changed the
graphics backend defaults to Metal 4 command encoding with MetalFX on, and made the per-bottle
graphics setting actually apply for the first time. That is a good change, and it can also silently
switch a bottle onto a backend the Steam client cannot draw with.

Once you have a configuration that works, stop the nagging:

```bash
BID=$(defaults read /Applications/Whisky.app/Contents/Info CFBundleIdentifier)
defaults write "$BID" SUEnableAutomaticChecks -bool false
defaults write "$BID" SUAutomaticallyUpdate  -bool false
```

And keep a way back. [`whisky-version.sh`](whisky-version.sh) in this repo installs any tagged
release, backs up the current app first, and clears the quarantine flag:

```bash
chmod +x whisky-version.sh
./whisky-version.sh                # list available releases
./whisky-version.sh app-v3.7.0     # install that one
```

> **Paste carefully**
> Write scripts to a file with a quoted heredoc (`cat > f.sh <<'EOF'`). Pasting a multi-line script
> straight into zsh runs it line by line, which is how you end up deleting an app before the line
> that reinstalls it.

---

## 3. Create the bottle

A bottle is a Wine prefix — a self-contained fake Windows install. Keep it on your internal disk. It
is only a couple of gigabytes on its own, and putting it on an external volume adds a failure mode
for nothing: unmount the drive while Whisky is running and the bottle can be left inconsistent.

Set the Windows version to **Windows 10**, not 11. The fork's own documentation uses Windows 10 as
the baseline for Steam, and it avoids a class of version-detection oddities.

Game files do not need to be in the bottle. A Steam library folder can sit on any external APFS
volume and be added to Steam later — that is how you keep a 37 GB game off a 109 GB boot disk.

---

## 4. Settings for the Steam client

The Steam client and the game want opposite graphics settings. Configure the client first, get
logged in, then flip the graphics for play. These are the client settings:

| Setting | Value | Why |
|---|---|---|
| Launcher Compatibility Mode | On | Added in 3.6.0; applies the fork's Steam profile |
| Detection Mode | Automatic | Lets it identify Steam by itself |
| Locale Override | English (en_US.UTF-8) | steamwebhelper crashes parsing dates in some locales |
| Windows Version | Windows 10 | Documented baseline |
| DXVK | On | Makes the client UI usable |
| D3DMetal / MetalFX | Off | Not needed by the client; a source of blank windows |
| Network timeout | 90 s or more | Stops downloads dropping |

And three environment variables on the bottle:

```
LC_ALL=en_US.UTF-8
STEAM_DISABLE_CEF_SANDBOX=1
WINE_FORCE_HTTP11=1
```

The first two are what the fork's
[launcher documentation](https://github.com/frankea/Whisky/blob/main/docs/LauncherTroubleshooting.md)
requires. The third works around Wine's HTTP/2 implementation, which is the reason Steam downloads
famously stall at 99%.

---

## 5. Install Steam

Whisky 3.7.0 has launcher profiles for Steam, Epic, EA, Battle.net and others — if there is a
one-click Steam option in your build, use it. Otherwise fetch the Windows installer and run it
inside the bottle:

```bash
curl -L -o ~/Downloads/SteamSetup.exe \
  https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe
```

Expect the client UI to feel sluggish. That is normal and says nothing about how the games will run
— the launcher is a Chromium app being translated twice over, while the game talks to the GPU almost
directly.

---

## 6. Reuse an existing library

If you have ever downloaded the game before — under CrossOver, an older bottle, a second drive — do
not let Steam download it again. Steam recognises any folder that contains a `steamapps` directory.
Add it under **Settings → Storage → Add Drive**, pointing at the folder above `steamapps`.

Check the manifest before and after. A fully installed game reads `StateFlags 4`, with the two byte
counts equal:

```bash
grep -E "name|StateFlags|BytesDownloaded|BytesToDownload" \
  "/path/to/library/steamapps/appmanifest_1479730.acf"
```

```
"name"              "Commandos: Origins"
"StateFlags"        "4"
"BytesToDownload"   "15994471216"
"BytesDownloaded"   "15994471216"
```

The number in the filename is the Steam AppID — 1479730 here. If Steam has already begun
re-downloading into a new library, you can copy the complete game folder into that library's
`common` directory and use **Verify integrity of game files**; Steam checksums what is there instead
of fetching it again.

---

## 7. Graphics for the game

Now invert the client settings. This is the part most guides get wrong:

> **The rule**
> **DXVK does not implement Direct3D 12.** It covers D3D9 through D3D11. Any modern D3D12 title —
> most Unreal Engine 5 games, Commandos: Origins included — needs D3DMetal, Apple's Game Porting
> Toolkit translation layer.

| Setting | Steam client | D3D12 game |
|---|---|---|
| DXVK | On | Off |
| D3DMetal | Off | On |
| MetalFX | Off | On, unless unstable |
| DirectX Raytracing | Off | Off to start |

If the game launches to a black window or crashes on start, turn MetalFX off first — it is the
newest code in the stack. Some Unreal titles also accept `-dx11` as a Steam launch option, which
puts you back on the DXVK path and is worth trying if D3DMetal misbehaves.

---

## 8. Fix the audio

The game ran perfectly and was completely silent. This one is worth knowing about because it
produces no error anywhere.

First, isolate the layer. In the bottle, run `winecfg`, open the **Audio** tab and use its test
button. macOS-level sound working while Wine's test is silent means the problem is Wine's CoreAudio
driver, not the game and not your Mac.

Then look at your output device's sample rates:

```bash
system_profiler SPAudioDataType | grep -A6 -i "output\|default"
```

The culprit in my case was a USB speakerphone reporting **48000 Hz output and 16000 Hz input**.
Wine's CoreAudio driver opens both directions when it initialises, and the mismatch leaves it
producing nothing at all, silently.

**The fix that worked:** switch the Mac's output to a device whose rates agree — the built-in
speakers, at a straight 48000 Hz — and relaunch. Sound came back immediately.

If you want to keep using the headset, two things are worth trying, though I have not verified
either:

- Open **Audio MIDI Setup**, select the device, and set its input format to 48000 Hz so both
  directions match.
- In `winecfg`'s Audio tab, set the input device to none — a game does not need a microphone, and
  Wine then never opens the mismatched side.

> **Restart after changing**
> Wine reads the audio device once, at process start. Changing your Mac's output device while the
> game is running does nothing — quit and relaunch.

If Wine sees no output device at all, the driver itself did not load. Force it and look at the debug
output:

```bash
wine reg add "HKCU\Software\Wine\Drivers" /v Audio /t REG_SZ /d coreaudio /f
WINEDEBUG=+coreaudio wine winecfg 2>&1 | tail -40
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Bottles listed but every click does nothing | Ghost entries — the bottle folder is no longer at the recorded path | Check `defaults read com.franke.Whisky` for `selectedBottleURL`, then confirm the folder exists |
| Bottle folder gone | Deleting a bottle in the UI moves it to the volume's trash, it does not erase it | Look in `/Volumes/<name>/.Trashes/$(id -u)/` before assuming it is lost |
| App runs from a path that doesn't exist | macOS App Translocation — a quarantined app runs from a random read-only copy | `xattr -dr com.apple.quarantine` on the bundle, and keep it in `/Applications` |
| steamwebhelper is not responding | Locale parsing crash in the CEF helper | Launcher Compatibility Mode on, `LC_ALL=en_US.UTF-8` |
| Downloads stall near 99% | Wine's HTTP/2 implementation | `WINE_FORCE_HTTP11=1`, network timeout 90 s |
| Game runs, no sound | Input and output sample rates differ on the active device | Switch output to a device with matching rates and relaunch |
| Black window on launch | Graphics backend the title can't use | MetalFX off, then D3DMetal on with DXVK off for D3D12 titles |

---

## Recovering a lost bottle

This is the single most useful thing in the guide. Whisky, Finder and most cleanup tools do not
delete folders on an external volume — they move them to a hidden per-user trash on that volume. A
39 GB bottle with a full Steam install inside it survived exactly this way.

```bash
U=$(id -u)
sudo ls -la "/Volumes/MyDrive/.Trashes/$U/"
sudo du -sh  "/Volumes/MyDrive/.Trashes/$U/"*/
sudo find    "/Volumes/MyDrive/.Trashes/$U" -maxdepth 6 -iname "steam.exe"
```

Bottles are named as UUIDs. Find the one with a `drive_c` inside, move it back, and fix the
ownership the `sudo` left behind:

```bash
U=$(id -u)
B=D7A49FD1-A81B-426C-8D76-AF7155399261
sudo mv "/Volumes/MyDrive/.Trashes/$U/$B" /Volumes/MyDrive/Whisky/Bottle/
sudo chown -R "$(id -un):staff" "/Volumes/MyDrive/Whisky/Bottle/$B"
```

> **Check before you empty**
> Emptying the trash on a volume is irreversible and takes the bottles with it. Recover first, verify
> the setup works, and only then reclaim the space — there was over 100 GB of recoverable bottles
> sitting in two volume trashes here.

---

## References

- [frankea/Whisky](https://github.com/frankea/Whisky) — the maintained fork
- [Launcher troubleshooting documentation](https://github.com/frankea/Whisky/blob/main/docs/LauncherTroubleshooting.md)
- [ProtonDB](https://www.protondb.com/) — compatibility reports
- [Apple — upcoming changes to Rosetta support](https://developer.apple.com/news/?id=w5ngl9k2)
- [CodeWeavers — CrossOver](https://www.codeweavers.com/)

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — use it, adapt it, credit it.
