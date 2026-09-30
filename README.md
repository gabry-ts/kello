<div align="center">

<img src="docs/images/icon.png" width="128" alt="Kello icon">

# Kello

**A calendar for your menu bar.**

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](#requirements)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](https://www.gnu.org/licenses/gpl-3.0.html)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/popover-dark.png">
  <img src="docs/screenshots/popover-light.png" alt="Kello's menu bar popover" width="320">
</picture>

</div>

## Features

- Menu bar date and time, with a custom pattern or 12/24-hour clock
- Month grid with week numbers and holidays
- Agenda with a "Next up" card and one-click Join on calls
- Quick entry: "Lunch with Sara friday 1pm" parses itself
- Extra time zone clocks in the popover
- Global shortcut, meeting notifications, launch at login

## Install

Download the latest `.dmg` from [Releases](https://github.com/gabry-ts/kello/releases), or:

```sh
brew install --cask gabry-ts/tap/kello
```

Kello updates itself automatically after that.

## Requirements

macOS 26 or later, Apple Silicon or Intel; grants calendar and reminders access on first launch.

## Build from source

```sh
./scripts/build.sh   # build/Kello.app
open build/Kello.app
```

## Privacy

All your data stays on your Mac: Kello reads and writes calendars and reminders through EventKit and never sends them anywhere.

## License

GNU General Public License v3.0. Copyright (C) 2026 Gabriele Partiti.

## Buy me a coffee

Kello is free. If it helps, you can [buy me a coffee](https://buymeacoffee.com/gabrielepartiti).
