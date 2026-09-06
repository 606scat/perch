# Privacy

Perch has no account system, analytics SDK, advertising, or telemetry endpoint.

- **Local content:** notes, drafts, snippets, project shortcuts, saved clipboard text, habits, dates, colors, QR text, text-tool input, drawings, and preferences are stored in a JSON file on your Mac. Backups contain the same information. These files are not encrypted by Perch; your macOS account and disk protections apply.
- **Files:** the tray stores paths and security-scoped bookmarks to existing files. Removing a tray item keeps the original file.
- **Clipboard:** capture happens when you click the capture button. Perch does not run a clipboard watcher and rejects text that its source marks as private, concealed, or transient. A source app may omit those markers, so choose what you save.
- **Apple Reminders:** access is optional. Perch displays and edits the list you choose. Your macOS account controls Reminders synchronization.
- **Relax:** ambient tracks are bundled with the app. Optional spoken guidance uses macOS speech synthesis. Perch does not record audio or request microphone access.
- **Updates:** Sparkle requests the update feed and release downloads from GitHub over HTTPS. GitHub receives ordinary connection data such as your IP address. System-profile reporting is disabled. Automatic checks are optional; installations require your choice.
- **Links:** opening a project website or sharing a file uses the chosen app or macOS share service. Those destinations have their own privacy practices.

Use **Settings → Show local data folder** to inspect the stored file. Removing Perch.app does not remove this data. If you choose to delete your data, close Perch first and remember to review its backup folders too.
