# huddlz

huddlz is a service that helps organizers and communities bring people
together in person. This repository contains the application source and
documentation for contributors and readers.

## Documentation

### Project direction

- [Vision](docs/vision.md) describes the project's purpose, values, and goals.
- [Domain model and access rules](docs/domain-model-and-access-rules.md)
  documents the domain model and permissions.

### Domain and feature specifications

- [Group membership](docs/group_membership.md) defines membership roles,
  verification, and access rules.
- [Email notifications](docs/notifications.md) specifies notification
  categories, triggers, and delivery rules.
- [API follow-ups](docs/api-followups.md) records deferred work for the
  JSON:API and GraphQL surfaces.

### Contributing

- [Testing](docs/testing.md) explains the project's test-first development
  approach.
- [Commit style](docs/commit-style.md) contains the commit-message guidelines.

## Local development

Install `vips` and the language runtimes defined in
[`.mise.toml`](.mise.toml), then run:

```sh
mise install
mix setup
mix phx.server
```

`mix setup` creates local environment files from the checked-in examples when
needed. Run the test suite with `mix test`.

## License

The source is licensed under the [Business Source License 1.1](LICENSE.md).
Review the license for the applicable use restrictions and change-license
terms.
