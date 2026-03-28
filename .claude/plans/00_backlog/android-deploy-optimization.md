# Android Deploy Optimization {bolt}
<!-- priority: 8 -->
<!-- tags: android, deploy, performance -->

> Speed up on-device deploy and fix app restart after install.

## Problems

1. **Slow build**: `gradlew assembleDebug` from the Mac agent is much slower than Android Studio's incremental build. Android Studio uses the Gradle daemon with hot caches; the terminal command cold-starts Gradle each time.
2. **No app restart**: `adb shell am force-stop` + `am start` doesn't reliably restart the app after install (the install itself may kill the process before the restart command runs).

## Potential Improvements

- Use `./gradlew assembleDebug --daemon` to keep Gradle daemon warm between deploys
- Skip `clean` and rely on incremental builds
- Use `adb install -r -t` with `adb shell am start -S` (force stop + start in one)
- Add a short delay between install and restart
- Consider using `adb shell monkey -p com.cloude.app -c android.intent.category.LAUNCHER 1` as alternative restart method
- Explore running the Gradle daemon persistently via the Mac agent

**Files:** `android/app/src/main/java/com/cloude/app/UI/deploy/DeploySheet.kt`
