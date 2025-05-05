# Huddlz

Huddlz is a social networking platform focused on facilitating real-life meetups and events, prioritizing in-person connections over digital interactions. The platform aims to support tech meetup organizers and other community builders with tools for event management and attendee coordination.

[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](LICENSE.md)

## Current Features

- **Soirée Listing** - Discover upcoming discussion events directly on the landing page
- **Search Functionality** - Find soirées by keyword across titles and descriptions
- **Magic Link Authentication** - Secure, passwordless login via email

### Project Status

Huddlz is under active development. The landing page with soirée listings has been implemented, providing immediate value to users visiting the site. Users can browse available soirées and search for events matching their interests without requiring authentication.

## Technology Stack

- **Backend**: Elixir with Phoenix Framework
- **Frontend**: Phoenix LiveView for interactive UI components
- **Data Layer**: Ash Framework for domain modeling
- **Authentication**: Ash Authentication with magic link email login
- **Database**: PostgreSQL
- **Testing**: Cucumber/Gherkin for behavior-driven development

## Getting Started

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Development

### Testing

* Run all tests: `mix test`
* Run a specific test file: `mix test path/to/test_file.exs`
* Run Cucumber features: `mix test test/features/`

### Code Quality

* Format code: `mix format`

## Contributing

* [Commit Style Guidelines](docs/commit-style.md) - Please follow these guidelines when contributing to this project
* This project follows behavior-driven development with Cucumber - see [Testing Guidelines](docs/testing.md)

## Documentation

* [Vision](docs/vision.md) - Project vision and goals
* [Testing](docs/testing.md) - Testing approach and guidelines

## Deployment

Ready to run in production? Please [check the Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## License

Huddlz is licensed under the [Business Source License 1.1](LICENSE.md) (BSL 1.1). This license:

* Allows you to freely use, modify, and distribute the software for non-commercial purposes
* Allows contributions to the project
* Restricts commercial use without a separate agreement
* Automatically converts to Apache License 2.0 5 years after the release of v1.0.0

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
