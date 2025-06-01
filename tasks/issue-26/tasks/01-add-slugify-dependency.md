# Task 1: Add Slugify Dependency

## Objective
Add the Slugify library to the project for consistent slug generation.

## Steps

1. **Update mix.exs**
   - Add `{:slugify, "~> 1.3"}` to the deps function
   - Place it in the appropriate section with other dependencies

2. **Install Dependency**
   ```bash
   mix deps.get
   ```

3. **Verify Installation**
   - Start iex: `iex -S mix`
   - Test the library:
   ```elixir
   Slug.slugify("Hello World!")
   # Should return "hello-world"

   Slug.slugify("Phoenix Elixir Meetup")
   # Should return "phoenix-elixir-meetup"
   ```

## Acceptance Criteria
- [ ] Slugify added to mix.exs
- [ ] Dependencies fetched successfully
- [ ] Library works in iex console
- [ ] Basic slug generation tested

## Notes
- Slugify is the most popular Elixir slug library
- Supports Unicode transliteration
- Well-maintained with good documentation