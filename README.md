# Keller Solutions Recipe Grabber

Paste links to recipes from almost any recipe site and get a clean copy of each one: title, photo, times, ingredients, directions, nutrition, and credits. Recipe Grabber reads the schema.org recipe data that most recipe sites publish.

## Setup

Requires Ruby 4.0.10 (see `.ruby-version`). No database.

```sh
bin/setup      # installs gems and starts the server at http://localhost:3000
```

## Quality gate

```sh
bin/ci         # RuboCop, bundler-audit, Brakeman, tests (100% line coverage required)
```

CI runs the same checks on every pull request.
