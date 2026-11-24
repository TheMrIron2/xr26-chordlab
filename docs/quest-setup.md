# Quest setup and deployment

The committed `Meta Quest` Android preset selects **OpenXR**, **arm64-v8a**, and package `org.chordlab.app`. It uses the prebuilt APK templates with Gradle disabled. Godot 4.6 and later support direct Android XR export, so try this preset first. If the APK installs but fails to launch in immersive XR, check the OpenXR startup log and try Godot's documented device-specific Gradle setup with the Meta option from OpenXR Vendors. [Godot 4.7 XR deployment](https://docs.godotengine.org/en/4.7/tutorials/xr/deploying_to_android.html)

## Prepare the development machine

1. Install the **Godot 4.7.2 export templates** using Editor → Manage Export Templates. The editor and templates must match exactly.
2. Configure a Java SDK and Android SDK in Editor Settings → Export → Android. Godot recommends OpenJDK 17. Android Studio's bundled JDK may also work if compatible with this Godot version.
3. Install the SDK platform and build tools required by **Godot 4.7.2**. Use the exporter diagnostics rather than assuming package versions from an older tutorial are sufficient.
4. Open Project → Export → **Meta Quest** and resolve any configuration errors. Create a local `builds` folder before exporting to `builds/chordlab.apk`.
5. Export a **debug APK** for the first headset test. A release signing key is unnecessary for this development check. Local credentials and APKs are ignored by Git.

See [Android export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) for the SDK and Java paths. The current preset uses the packaged APK templates, so installing a Gradle build template is not needed unless a plugin is added.

## Connect the headset

1. Enable developer mode on the Quest, connect it by USB, and accept the USB debugging prompt inside the headset. Windows may require the Meta ADB driver. Follow the headset setup linked from [Godot's deployment page](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html).
2. Confirm the headset is listed as `device`, rather than `unauthorized`, using the SDK's `platform-tools/adb`:

   ```powershell
   adb devices -l
   ```

3. Use Godot's one-click deploy with the runnable Meta Quest preset, or install the exported APK:

   ```powershell
   adb install -r builds/chordlab.apk
   ```

4. Launch **Chord Lab** from the headset's installed development apps. Use the controllers rather than hand tracking.

If `adb` is not on PATH, use its full path. The SDK found on this development machine is `C:\Users\dwelc\AppData\Local\Android\Sdk`; that machine-specific path is not saved into the project.

## Keyboard hardware checks

Record the Quest model, OS version, Godot version, date, and outcome in `development-log.md`.

- The application starts in immersive XR with head tracking and the opaque background.
- Both controller rays track the aim direction and disappear when tracking is lost. Check all keys from C4 to D5, including the black keys and the white keys immediately beside them.
- One trigger squeeze toggles one note. Holding it does not toggle repeatedly; releasing then pressing permits another selection.
- All pitches produce distinct audible notes at a comfortable volume.
- A/X plays selected notes together and identifies C major and C minor. Try adding a fourth key to hear the selection and check the feedback. B/Y clears highlights and stops playback.
- Grip repositions the station correctly when standing, seated, or facing another direction.
- Text is readable and keys are easy to target at the actual headset resolution.
- Removing and replacing the headset, recentering, and relaunching do not break interaction.

## Current verification limits

On 24 November 2026, the Android SDK and Android Studio's bundled JDK were present. The debug exporter reported missing Godot 4.7.2 Android templates and a blank Java SDK path in Editor Settings. ADB listed zero devices. APK export, installation, immersive startup, target comfort, and audible volume checks remain pending.
