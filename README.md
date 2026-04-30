# TahoReader – Android Tachograph Card Viewer/Reader

Android version of my previous tachograph‑reading project.
The original C/C++ implementation is available here:
https://github.com/ekonaser/TahoReader

## AI‑Assisted Development

Most of the UI and general structure were developed with the help of an AI agent.
However, all data handling, parsing, reading logic, and binary interpretation are
implemented manually, based on the original C/C++ project.

## Project Idea

TahoReader is a mobile application designed to read and display data from a digital tachograph card.
Its purpose is to give drivers and companies a simple, accessible way to view:

- driver personal data
- activity logs (driving, rest, work, availability)
- infringements
- vehicle usage
- GNSS locations
- last upload timestamps
- .ddd file contents
- direct card reading via USB ISO‑7816 reader

Since there are very few free or open‑source tools for tachograph data on mobile devices,
I decided to build my own solution.

I am not a professional programmer, so some parts of the logic or data interpretation
may contain mistakes — this project is both a learning experience and a practical tool.