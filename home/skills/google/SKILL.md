---
name: google
description: Access Google services (Gmail, Calendar, Drive, Docs, Sheets, Contacts, Tasks) via gogcli. Use for reading/sending email, managing calendar events, accessing Drive files, and other Google Workspace operations.
---

# Google Services (gogcli)

CLI access to Gmail, Calendar, Drive, Docs, Sheets, Contacts, Tasks, and more.

## Account

**Always use account: `justinbot78702@gmail.com`**

## Invocation

```bash
nix run ~/configs#gog -- --account=justinbot78702@gmail.com <command> [args]
```

Add `--json` for machine-readable output (preferred for parsing).

## Common Commands

All examples below assume `--account=justinbot78702@gmail.com` is passed.

### Gmail

```bash
# List labels
nix run ~/configs#gog -- --account=justinbot78702@gmail.com gmail labels list

# Search emails (returns threads)
nix run ~/configs#gog -- --account=justinbot78702@gmail.com gmail search "from:boss subject:urgent"

# Search messages (not threads)
nix run ~/configs#gog -- --account=justinbot78702@gmail.com gmail messages "is:unread"

# Read a thread
nix run ~/configs#gog -- --account=justinbot78702@gmail.com gmail read <thread-id>

# Send email
nix run ~/configs#gog -- --account=justinbot78702@gmail.com gmail send --to "recipient@example.com" --subject "Hello" --body "Message body"

# Reply to thread
nix run ~/configs#gog -- --account=justinbot78702@gmail.com gmail reply <thread-id> --body "Reply text"
```

### Calendar

```bash
# List calendars
nix run ~/configs#gog -- --account=justinbot78702@gmail.com calendar list

# Show upcoming events (default: today)
nix run ~/configs#gog -- --account=justinbot78702@gmail.com calendar events

# Events for specific range
nix run ~/configs#gog -- --account=justinbot78702@gmail.com calendar events --from "2024-01-15" --to "2024-01-20"

# Create event
nix run ~/configs#gog -- --account=justinbot78702@gmail.com calendar create --title "Meeting" --start "2024-01-15T10:00:00" --end "2024-01-15T11:00:00"

# Delete event
nix run ~/configs#gog -- --account=justinbot78702@gmail.com calendar delete <event-id>
```

### Drive

```bash
# List files
nix run ~/configs#gog -- --account=justinbot78702@gmail.com drive list

# Search files
nix run ~/configs#gog -- --account=justinbot78702@gmail.com drive search "name contains 'report'"

# Download file
nix run ~/configs#gog -- --account=justinbot78702@gmail.com drive download <file-id> --output ./local-file.pdf

# Upload file
nix run ~/configs#gog -- --account=justinbot78702@gmail.com drive upload ./local-file.pdf

# Get file info
nix run ~/configs#gog -- --account=justinbot78702@gmail.com drive info <file-id>
```

### Docs/Sheets/Slides

```bash
# Export Google Doc as text/markdown
nix run ~/configs#gog -- --account=justinbot78702@gmail.com docs export <doc-id> --format txt

# Read sheet data
nix run ~/configs#gog -- --account=justinbot78702@gmail.com sheets get <spreadsheet-id> --range "Sheet1!A1:D10"

# Update sheet cells
nix run ~/configs#gog -- --account=justinbot78702@gmail.com sheets update <spreadsheet-id> --range "Sheet1!A1" --values '[["value1", "value2"]]'
```

### Contacts

```bash
# List contacts
nix run ~/configs#gog -- --account=justinbot78702@gmail.com contacts list

# Search contacts
nix run ~/configs#gog -- --account=justinbot78702@gmail.com contacts search "john"

# Get contact details
nix run ~/configs#gog -- --account=justinbot78702@gmail.com contacts get <contact-id>
```

### Tasks

```bash
# List task lists
nix run ~/configs#gog -- --account=justinbot78702@gmail.com tasks lists

# List tasks in a list
nix run ~/configs#gog -- --account=justinbot78702@gmail.com tasks list <tasklist-id>

# Create task
nix run ~/configs#gog -- --account=justinbot78702@gmail.com tasks create <tasklist-id> --title "Do the thing"

# Complete task
nix run ~/configs#gog -- --account=justinbot78702@gmail.com tasks complete <tasklist-id> <task-id>
```

## Tips

- Use `--json` flag for structured output when parsing results
- Use `--plain` for TSV output (good for simple scripts)
- Gmail search uses standard Gmail query syntax
- Date/time formats: ISO 8601 (`2024-01-15T10:00:00`) or natural language
- File IDs can be extracted from Google URLs: `docs.google.com/document/d/<FILE-ID>/edit`

## Auth Troubleshooting

If auth fails, ask the user to run:

```bash
nix run ~/configs#gog -- auth add justinbot78702@gmail.com
```
