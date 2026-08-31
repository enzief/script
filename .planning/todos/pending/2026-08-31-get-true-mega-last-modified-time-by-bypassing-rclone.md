---
created: 2026-08-31T15:33:08.240Z
title: Get true MEGA last-modified time by bypassing rclone
area: general
severity: major
files: []
---

## Problem

`rclone backend features mega:` reports `"Precision": 3153600000000000000` — rclone's internal `ModTimeNotSupported` sentinel (100 years in nanoseconds). This means the `ModTime` field `rclone lsjson` returns for the `mega:` remote is not a trustworthy last-modified value.

Verified on `mega:devicesync/20220109_megasync/2022-05-11 at 7.22 AM.mov`:
- `rclone lsjson` ModTime: `2022-05-29T22:52:05-06:00` (looks like upload/added time)
- MEGA web UI "Last modified": `2022-05-11 05:24` — matches the corresponding local file's mtime (`/media/enzief/wdhdd/mega_wdhdd/devicesync/macm1/Photo Booth Library/Pictures/Movie on 2022-05-11 at 7.22 AM.mov`, mtime `2022-05-11 05:24:06 -0600`) exactly.

So MEGA does store/expose the real last-modified value somewhere, but rclone's mega backend (backed by `go-mega`) doesn't surface it through `lsjson`. This blocks any reliable date-based (as opposed to size-only) matching between local files and files on the `mega:` remote.

## Solution

TBD — investigate MEGA's official API or MEGAcmd (not currently installed on this machine) to fetch the real "Last modified" value the web UI displays, as an alternative to rclone for this specific metadata field.
