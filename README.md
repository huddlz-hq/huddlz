# huddlz

huddlz is a social networking platform focused on facilitating real-life meetups and events, prioritizing in-person connections over digital interactions. The platform aims to support tech meetup organizers and other community builders with tools for event management and attendee coordination.

> **Naming Convention**: In huddlz, a singular event is called a "huddl" and multiple events are called "huddlz", matching the platform name. For branding purposes, we always use lowercase in UI and documentation.

[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](LICENSE.md)

## Current Features

- **Huddl Listing** - Discover upcoming discussion events directly on the landing page
- **Search Functionality** - Find huddls by keyword across titles and descriptions
- **Password Authentication** - Secure login with password reset functionality

### Project Status

Huddlz is under active development. The landing page with huddl listings has been implemented, providing immediate value to users visiting the site. Users can browse available huddls and search for events matching their interests without requiring authentication.

## Technology Stack

- **Backend**: Elixir with Phoenix Framework
- **Frontend**: Phoenix LiveView for interactive UI components
- **Data Layer**: Ash Framework for domain modeling
- **Authentication**: Ash Authentication with password-based login
- **Database**: PostgreSQL
- **Testing**: Cucumber/Gherkin for behavior-driven development

## Getting Started

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Development

### Development Workflow

Huddlz follows a streamlined development process optimized for solo development and AI collaboration:

1. **Requirements Definition**: Define feature requirements using `/define`
2. **Implementation Planning**: Plan implementation approach using `/plan`
3. **Development**: Implement the solution using `/build`
4. **Verification**: Review and test using `/verify`
5. **Knowledge Capture**: Extract learnings using `/reflect`

See [Development Lifecycle](docs/development_lifecycle.md) for detailed information.

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
* [Testing Approach](docs/testing_approach.md) - PhoenixTest patterns and best practices
* [PhoenixTest Migration](docs/phoenix_test_migration.md) - Guide for migrating tests to PhoenixTest
* [Development Lifecycle](docs/development_lifecycle.md) - Complete development workflow from requirements to implementation

## Deployment

### Required Environment Variables

The following environment variables must be set in production:

* `DATABASE_URL` - PostgreSQL database connection string
* `SECRET_KEY_BASE` - Secret key for session encryption (generate with `mix phx.gen.secret`)
* `TOKEN_SIGNING_SECRET` - Secret for signing authentication tokens
* `SENDGRID_API_KEY` - SendGrid API key for sending emails (required for password reset functionality)

### Optional Environment Variables

* `RENDER_EXTERNAL_HOSTNAME` - Hostname for the application (defaults to "huddlz.com")
* `PORT` - Port to bind to (defaults to 4000)
* `POOL_SIZE` - Database connection pool size (defaults to 10)

Ready to run in production? Please [check the Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html) for detailed instructions.

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
