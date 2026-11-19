# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Grab recipes from any site that publishes schema.org recipe data, several links at a time, with N/A for missing details (#3)
- Plain-language message for each link that can't be grabbed, while the rest still display; limits of 1 to 10 links per grab (#4)

### Changed

- Rebuilt on Ruby 4.0.10 and Rails 8.1 with a responsive, keyboard-accessible home page (#2)

### Security

- Recipe links are fetched only over http(s) from public addresses, with redirect re-checks, timeouts, and a 2 MB cap; the legacy `Kernel#open` command-injection hole is gone (#3)
- One deadline covers every redirect hop, environment proxies are ignored, and grabs are limited to 10 per minute per visitor (#4)
- Ruby 4.0.10 for the Onigmo regexp and String case-conversion fixes; CI scans gems with the shared Keller Solutions bundle-audit workflow, which fails on any open advisory

### Removed

- Rails 2.3 / Ruby 1.8.7 application, RVM and Heroku `.gems` configuration (#2)
