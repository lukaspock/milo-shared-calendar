# Swappable dummy icons

Every emoji used as an icon/illustration in the app is rendered through the
`AppImages` helper (see `lib/widgets/app_image.dart`). Each one tries to load a
PNG from this folder and falls back to the original emoji if the file is missing.

To replace an emoji with a real picture, just drop a PNG into this folder using
the matching file name below, then rebuild (`flutter run`). No code changes needed.

| File name                | Replaces | Used for                                  |
|--------------------------|----------|-------------------------------------------|
| `dummy_wave.png`         | 👋       | Greetings (onboarding, home header)       |
| `dummy_calendar.png`     | 📅       | Calendar icon / illustration (everywhere) |
| `dummy_people.png`       | 👥       | Members / shared-with                     |
| `dummy_star.png`         | ⭐       | Highlights / featured                     |
| `dummy_party.png`        | 🎉       | Success / celebration                     |
| `dummy_sparkles.png`     | ✨       | Decorative sparkle                        |
| `dummy_sprout.png`       | 🌱       | New / getting started                     |
| `dummy_poll.png`         | 📊       | Polls                                     |
| `dummy_note.png`         | 📝       | Notes / description                       |
| `dummy_flag.png`         | 🏁       | End time / finish                         |
| `dummy_envelope.png`     | ✉️       | Email / account creation                  |
| `dummy_mailbox.png`      | 📬       | Check your inbox (verify email)           |
| `dummy_lock.png`         | 🔐       | Password                                  |
| `dummy_bell.png`         | 🔔       | Notifications / reminders                 |
| `dummy_target.png`       | 🎯       | Confirmed / goal                          |
| `dummy_globe.png`        | 🌐       | Web / Google calendar                     |
| `dummy_phone.png`        | 📱       | On-device / device calendar               |
| `dummy_sad.png`          | 😕       | Empty / error states                      |
| `dummy_check.png`        | ✅       | Connected / done                          |

PNGs should be roughly square; they are scaled to fit the icon size at each call site.
