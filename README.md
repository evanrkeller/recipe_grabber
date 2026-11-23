# Keller Solutions Recipe Grabber

Paste links to recipes from almost any recipe site and get a clean copy of each one: title, photo, times, ingredients, directions, nutrition, and credits. Recipe Grabber reads the schema.org recipe data that most recipe sites publish.

## Setup

Requires Ruby 4.0.9 (see `.ruby-version`). No database.

```sh
bin/setup      # installs gems and starts the server at http://localhost:3000
```

## Quality gate

```sh
bin/ci         # RuboCop, bundler-audit, Brakeman, tests (100% line coverage required)
```

CI runs the same checks on every pull request.

## Project management

- **Tracker:** GitHub Issues on [`evanrkeller/recipe_grabber`](https://github.com/evanrkeller/recipe_grabber/issues). Every change starts from an issue.
- **Find work:** `gh issue list -R evanrkeller/recipe_grabber`; the `status:in-progress` and `status:in-review` labels mark work underway.
- **Add a ticket:** `gh issue create -R evanrkeller/recipe_grabber`. Write it as a user story (In order to / As a / I want) with testable acceptance criteria. Security fixes get the `security` label and a `priority:` label.
- **Link the work:** reference `#<number>` in commits and put `Closes #<number>` in the pull request body.
- **Agent access:** agents use the GitHub CLI (`gh`) under the developer's own signed-in account (`gh auth status`); no extra token is needed. Keller Solutions agents follow the `managing-tickets` skill in the keller-solutions-core plugin.
