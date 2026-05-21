# Garmin Meditation Timer

A Connect IQ watch app that runs a three-phase meditation session: **Preparation → Meditation → Return**. Each phase auto-advances when the previous one ends.

## Setup screen

On launch, the app shows a setup screen where each phase duration is configurable from **0 to 180 minutes** (defaults: 1 / 20 / 3). Setting a phase to 0 skips it. The last-used durations are remembered across launches. Controls:

- **Up / Down:** move selection between phases and the `[ Start / Exit ]` row
- **Select:** increase the selected phase by 1 minute, or start the session when `[ Start / Exit ]` is highlighted
- **Back:** decrease the selected phase by 1 minute

Spanish (`es`) localization is included; the watch's system language picks it up automatically.

## During the session

The screen shows the current phase name, the remaining time as `MM:SS`, a `Step N / 3` indicator, a progress bar for the current phase, and live heart rate (`--` if unavailable).

Controls:

- **Select:** pause the session. After 3 seconds of being paused, the confirmation menu opens automatically.
- **Back:** advance ("lap") to the next phase. On the final phase, **Back** opens the confirmation menu instead.

At every phase transition (including completion) the watch plays a 5-pulse vibration cue. No audio.

## Confirmation menu

When the confirmation menu is open you see:

- **Continue** (only shown if the session was paused) — resume the session
- **Finish and save** — stop the activity and save it to Garmin activity history
- **Cancel activity** — stop the activity and discard it without saving

Use Up/Down to navigate, Select to confirm, Back to return to the session.

## Activity recording

The session is recorded as a `SPORT_MEDITATION` activity. It is **saved** when the flow completes naturally or when you pick *Finish and save*, and **discarded** when you pick *Cancel activity*.

## Notification blocking

Connect IQ has no cross-device API for third-party apps to suppress system notifications. Enable the watch's **Do Not Disturb** mode before starting if you want full notification blocking.

## Supported devices

See `manifest.xml` for the full product list.
