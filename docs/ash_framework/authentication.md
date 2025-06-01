# Ash Framework: Authentication

This document covers how to implement authentication in Phoenix applications using Ash Authentication.

## Table of Contents

- [Introduction](#introduction-to-ash-authentication)
- [Setting Up Authentication](#setting-up-authentication)
- [Router Configuration](#router-configuration)
- [Displaying Authentication Status](#displaying-authentication-status)
- [Authentication Strategies](#authentication-strategies)
- [Customizing Authentication](#customizing-authentication)
- [Benefits of Ash Authentication](#benefits-of-ash-authentication)
- [Common Customizations](#common-customizations)

## Introduction to Ash Authentication

Ash Authentication provides a comprehensive authentication system for Ash Framework applications with minimal setup. It supports multiple authentication strategies including:

- Password-based authentication
- Magic link authentication
- OAuth providers
- And more

## Setting Up Authentication

### Installation with Igniter

Ash provides the Igniter tool to streamline the setup process:

```bash
# Install the Igniter archive
mix archive.install hex igniter_new

# Install ash_authentication_phoenix with selected strategies
mix igniter.install ash_authentication_phoenix --auth-strategy magic_link,password
```

This command:
1. Adds necessary dependencies to your project
2. Creates authentication-related resources (like User and accounts domain)
3. Updates configuration files
4. Sets up routes

After installation, migrate your database to create the authentication tables:

```bash
mix ash_postgres.migrate
```

### Authentication Resource Structure

Ash Authentication creates these main resources:

1. **User Resource**: Represents authenticated users
2. **Token Resource**: Manages authentication tokens (for magic links, etc.)
3. **Account Domain**: Organizes user-related resources

The installer configures these resources with proper relationships and actions for authentication.

## Router Configuration

### Authentication Routes

The installer adds these routes to your router:

```elixir
# Basic authentication routes for login/logout
auth_routes AuthController, Helpcenter.Accounts.User, path: "/auth"
sign_out_route AuthController

# Sign-in route with configuration
sign_in_route register_path: "/register",
             reset_path: "/reset",
             auth_routes_prefix: "/auth",
             on_mount: [{HelpcenterWeb.LiveUserAuth, :live_no_user}],
             overrides: [
               HelpcenterWeb.AuthOverrides,
               AshAuthentication.Phoenix.Overrides.Default
             ]

# Password reset route
reset_route auth_routes_prefix: "/auth",
           overrides: [
             HelpcenterWeb.AuthOverrides,
             AshAuthentication.Phoenix.Overrides.Default
           ]
```

These routes provide:
- Registration at `/register`
- Sign in at `/sign-in`
- Sign out at `/sign-out`
- Password reset functionality at `/reset`

### Protected LiveView Routes

For LiveView routes that require authentication, configure them within an authentication session:

```elixir
scope "/", HelpcenterWeb do
  pipe_through :browser

  ash_authentication_live_session :authenticated_routes,
    on_mount: [{HelpcenterWeb.LiveUserAuth, :live_user_required}] do
    # Protected routes go here
    scope "/categories" do
      live "/", CategoriesLive
      live "/create", CreateCategoryLive
      live "/:category_id", EditCategoryLive
    end
  end
end
```

The `on_mount` hook ensures users are authenticated before accessing these routes. You can use different hooks:

- `:live_user_required`: User must be authenticated
- `:live_user_optional`: Authentication is optional
- `:live_no_user`: User must NOT be authenticated

## Displaying Authentication Status

To show authentication status in your templates, use the `@current_user` assign:

```heex
<div class="flex items-center justify-between">
  <!-- Logo -->
  <div class="text-3xl font-bold text-yellow-500">Zippiker</div>

  <!-- Authentication Section -->
  <div class="absolute inset-y-0 right-0 flex items-center pr-2 sm:static sm:inset-auto sm:ml-6 sm:pr-0">
    <!-- Show if user is logged in -->
    <div :if={@current_user}>
      <span class="px-3 py-2 text-sm font-medium text-yellow-500 rounded-md">
        {@current_user.email}
      </span>
      <a href="/sign-out" class="rounded-lg bg-zinc-100 px-2 py-1 text-[0.8125rem] font-semibold text-zinc-900 hover:bg-zinc-200/80">
        Sign Out
      </a>
    </div>

    <!-- Show if user is not logged in -->
    <a :if={is_nil(@current_user)} href="/sign-in" class="rounded-lg bg-zinc-100 px-2 py-1 text-[0.8125rem] font-semibold text-zinc-900 hover:bg-zinc-200/80">
      Sign In
    </a>
  </div>
</div>
```

## Authentication Strategies

### Password Authentication

The default setup includes password authentication with:
- Password hashing
- Password validation
- Registration form
- Login form

### Magic Link Authentication

Magic link authentication sends a one-time use link to the user's email:
1. User enters their email
2. System sends a magic link to that email
3. User clicks the link to authenticate
4. System validates the token and creates an authenticated session

For this to work in production, you need to configure email delivery in your application.

## Customizing Authentication

### Custom Form Overrides

You can customize the authentication forms by creating override modules:

```elixir
# In router.ex
sign_in_route register_path: "/register",
             reset_path: "/reset",
             auth_routes_prefix: "/auth",
             overrides: [
               HelpcenterWeb.AuthOverrides,  # Your custom overrides
               AshAuthentication.Phoenix.Overrides.Default
             ]
```

Then implement the overrides in `auth_overrides.ex`:

```elixir
defmodule HelpcenterWeb.AuthOverrides do
  # Custom form components and behavior
end
```

## Benefits of Ash Authentication

1. **Minimal Setup**: Full authentication system with just a few commands
2. **Multiple Strategies**: Support for various authentication methods
3. **Security Best Practices**: Follows security best practices by default
4. **Phoenix Integration**: Seamless integration with Phoenix and LiveView
5. **Extensibility**: Easy to customize and extend
6. **Consistency**: Maintains the Ash pattern of declarative resources

## Common Customizations

1. **Email Templates**: Customize email templates for magic links and password resets
2. **Registration Requirements**: Add custom fields to the registration form
3. **Authentication Flow**: Customize redirects and success/failure behavior
4. **User Interface**: Style the authentication forms to match your application

## Implementation Steps

### 1. Add Authentication Dependencies

```elixir
# In mix.exs
defp deps do
  [
    {:ash_authentication, "~> 3.11"},
    {:ash_authentication_phoenix, "~> 1.7"},
    # Other dependencies...
  ]
end
```

### 2. Configure User Resource

```elixir
defmodule Helpcenter.Accounts.User do
  use Ash.Resource,
    domain: Helpcenter.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :username, :string
    timestamps()
  end

  authentication do
    strategies [
      # Password strategy
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? true
      end,

      # Magic link strategy
      magic_link :magic_link do
        identity_field :email
      end
    ]
  end

  # Rest of resource definition...
end
```

### 3. Configure Email Delivery for Magic Links

```elixir
# In config/config.exs
config :ash_authentication,
  sender: MyApp.Mailer,
  from: {"My App", "auth@myapp.com"}

# In application.ex
def start(_type, _args) do
  children = [
    # Other children...
    {AshAuthentication.Supervisor, otp_app: :my_app}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 4. Testing Authentication

To test with magic links in development, check your logs for the magic link URL. For password authentication, you'll need to register an account and confirm it (also through the logs in development).