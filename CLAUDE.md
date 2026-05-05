# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal YouTube video/audio downloader. Rails 8.0 monolith with Vue 3 SPA frontend (Vite). Users submit a YouTube URL, pick `mp4` (720p / 1080p) or `mp3`, and the file is either streamed back from local disk or uploaded to OVH Object Storage (S3-compatible) and retrieved via a presigned URL.

The repo started as a Rails/Vue/Tailwind boilerplate, so some unused scaffolding (e.g. `app/frontend/stores/counter.js`) may still be around. Feel free to trim boilerplate leftovers when touching nearby code.

## Common Commands

### Development
```bash
foreman start -f Procfile.dev   # Rails + Vite together (recommended)
bin/rails s                     # Rails only (port 3000)
bin/vite dev                    # Vite only (HMR)
```

`yt-dlp` must be on `PATH` (override with `YT_DLP_BIN`). `ffmpeg` is required for mp4 merge / mp3 extraction.

### Database
```bash
rails db:create db:migrate
bundle exec annotaterb models   # Refresh schema annotations after migrations
```

### Tests (Minitest)
```bash
rails test
rails test test/path/to/file.rb
rails test test/path/to/file.rb:42
```

### Linting / Security
```bash
npm run lint[:fix]
bundle exec rubocop [-a]
bundle exec brakeman
bundle exec bundler-audit
```

## Architecture

### Download flow
1. `POST /api/downloads` → `Api::DownloadsController#create` builds a `Download` (status `pending`) and enqueues `DownloadJob` (GoodJob).
2. `DownloadJob` flips status to `processing`, calls `YtDlpService` (shells out to `yt-dlp` into `tmp/downloads/<id>/`), assigns `title`/`filename`/`file_size`.
3. If `storage == "cloud"`: uploads the file to OVH S3 via `OvhS3.client`, sets `s3_key`, deletes the local file. Otherwise the file stays under `tmp/downloads/<id>/`.
4. Status becomes `completed` (or `failed` with `error_message`). Failures wipe the local dir and re-raise so GoodJob records the error.
5. `GET /api/downloads/:id/file` either `send_file`s the local path or 302-redirects to a 5-min presigned S3 URL (`response_content_disposition` forces a download with the stored filename).
6. `DELETE` removes the row and best-effort deletes the local dir or the S3 object.

### Domain rules (`app/models/download.rb`)
- `FORMATS = %w[mp4 mp3]`, `QUALITIES = %w[original 720p]`, `STORAGES = %w[local cloud]`, `STATUSES = %w[pending processing completed failed]`.
- `quality` is required when `format == "mp4"` and ignored for mp3.
- `folder_id` is only allowed when `storage == "cloud"` (local downloads are unsorted by design).
- Scope: `Download.recent` (desc by `created_at`).

### S3 layout
`OvhS3` (`config/initializers/ovh_s3.rb`) is a thin wrapper around `Aws::S3::Client` pointed at OVH via `OVH_S3_{ACCESS_KEY,SECRET_KEY,REGION,ENDPOINT,BUCKET}`. Keys follow `downloads/user-<user_id>/<folder-slug-or-"unsorted">/<download_id>-<filename>` (see `DownloadJob#s3_key_for`). Folder names are `parameterize`d, so renaming a `Folder` does **not** rewrite existing keys.

### yt-dlp invocation (`app/services/yt_dlp_service.rb`)
- Metadata pass: `yt-dlp --dump-json --no-playlist`.
- Download pass uses `--print after_move:filepath` and reads the final path from the last non-empty stdout line — keep that invariant if you add flags that print to stdout.
- mp4 format selector caps at 1080p (`original`) or 720p and requires `ffmpeg` for the `+bestaudio` merge.

### Request flow
- `config/routes.rb` mounts Devise, API under `/api` (`folders`, `downloads` with a `:file` member route, `sessions#me`), and a catch-all `get '*path'` → `SpaController#index` constrained to non-xhr HTML requests so `/api/*` JSON isn't swallowed.
- `Api::BaseController` is the parent for API controllers; `ApplicationController` includes Pundit and `Pagy::Method`.
- Axios attaches the CSRF meta token (`app/frontend/plugins/axios.js`); Pinia stores live in `app/frontend/stores/`.

### Background jobs
GoodJob (PostgreSQL-backed, no Redis). The `downloads` table is the source of truth for job state; the job updates status fields directly so the UI can poll `/api/downloads` without inspecting GoodJob internals.

## Key Dependencies

**Backend:** Rails 8.0, PostgreSQL, Devise, Pundit, GoodJob, Pagy 43, PaperTrail, aws-sdk-s3
**Frontend:** Vue 3.5, Vite 5, Pinia, Vue Router, Axios, Tailwind 3.4
**External binaries:** `yt-dlp`, `ffmpeg`
**Runtime:** Ruby 3.3.5, Node 20.x
