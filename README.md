# Garmin Meditation Timer (v0)

This Connect IQ watch app runs a fixed meditation flow:

1. **Prepare:** 1 minute
2. **Meditate:** 20 minutes
3. **Return:** 3 minutes

Each phase automatically starts when the previous one ends.

## Alerts

At each phase transition (including completion), the watch vibrates for ~3 seconds in short pulses and does not play audio.

## Activity recording + meditation metrics

The app now starts an activity-recording session at launch and saves it when the flow completes (or when the app exits), so the meditation session is captured in Garmin activity history.

During the session, the app displays wellness metrics that are useful for meditation when available on-device:

- current heart rate
- stress score
- body battery

Values show as `--` on devices that do not expose those fields.

## Notification blocking

Connect IQ does not provide a reliable cross-device API for third-party apps to force-disable all system notifications.

For v0, the app is designed to keep the meditation flow uninterrupted inside the app UI, and you should enable your watch's system **Do Not Disturb** mode before starting if you want full notification blocking.
