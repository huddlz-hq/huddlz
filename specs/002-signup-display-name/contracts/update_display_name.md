# Contract: update_display_name Action

## Action Details

**Resource**: `Huddlz.Accounts.User`
**Action**: `update_display_name`
**Type**: Update
**Authorization**: User can only update their own display_name

## Purpose

Allows authenticated users to update their display name at any time after signup.

## Request Contract

### Input Parameters

```elixir
%{
  "display_name" => String.t()  # Required, 1-70 characters
}
```

### Actor Context

```elixir
%{
  actor: %User{id: actor_id}  # Must match the user being updated
}
```

### Validation Rules

**display_name**:
- Required (cannot be nil or empty string)
- Minimum length: 1 character
- Maximum length: 70 characters (updated from 30)
- Character set: All printable UTF-8 characters (letters, numbers, spaces, punctuation, emojis)
- No uniqueness constraint (duplicates allowed)
- Must not equal empty string (explicit validation)

### Example Valid Requests

```elixir
# Standard name change
user
|> Ash.Changeset.for_update(:update_display_name, %{
  display_name: "Jane Smith"
}, actor: user)
|> Ash.update()

# Change to single name
user
|> Ash.Changeset.for_update(:update_display_name, %{
  display_name: "Cher"
}, actor: user)
|> Ash.update()

# Add emoji
user
|> Ash.Changeset.for_update(:update_display_name, %{
  display_name: "Alex 🚀"
}, actor: user)
|> Ash.update()

# Use accented characters
user
|> Ash.Changeset.for_update(:update_display_name, %{
  display_name: "François Müller"
}, actor: user)
|> Ash.update()

# Maximum length (70 characters)
user
|> Ash.Changeset.for_update(:update_display_name, %{
  display_name: String.duplicate("A", 70)
}, actor: user)
|> Ash.update()
```

## Response Contract

### Success Response

**Status**: `{:ok, user}`

```elixir
{:ok, %Huddlz.Accounts.User{
  id: "550e8400-e29b-41d4-a716-446655440000",
  email: "user@example.com",
  display_name: "Jane Smith",                  # Updated display name
  updated_at: ~U[2025-10-01 12:30:00Z],       # Timestamp updated
  ...
}}
```

### Error Responses

#### Empty Display Name

```elixir
{:error, %Ash.Error.Invalid{
  errors: [
    %Ash.Error.Changes.InvalidAttribute{
      field: :display_name,
      message: "must not be empty",
      value: ""
    }
  ]
}}
```

#### Display Name Too Long

```elixir
{:error, %Ash.Error.Invalid{
  errors: [
    %Ash.Error.Changes.InvalidAttribute{
      field: :display_name,
      message: "length must be less than or equal to 70",
      value: "Very long name that exceeds the maximum..."
    }
  ]
}}
```

#### Missing Display Name

```elixir
{:error, %Ash.Error.Invalid{
  errors: [
    %Ash.Error.Changes.InvalidAttribute{
      field: :display_name,
      message: "must be present",
      value: nil
    }
  ]
}}
```

#### Unauthorized (wrong actor)

```elixir
{:error, %Ash.Error.Forbidden{
  errors: [
    %Ash.Error.Forbidden.Policy{
      message: "forbidden",
      facts: %{actor: %{id: "other-user-id"}},
      policy: "Users can update their own display_name"
    }
  ]
}}
```

## Behavioral Contracts

### Pre-conditions

- User is authenticated (actor present)
- Actor is updating their own record (id == actor.id)
- Display name meets validation requirements

### Post-conditions

- User's display_name is updated in database
- User's updated_at timestamp is updated
- Display name visible immediately in all contexts

### Side Effects

1. Database write: UPDATE users table
2. Timestamp update: updated_at field
3. No email notifications or other side effects

### Idempotency

Idempotent. Calling multiple times with same display_name results in same state (though updated_at will change).

## Authorization Contract

### Policy

```elixir
policy action(:update_display_name) do
  description "Users can update their own display_name"
  authorize_if expr(id == ^actor(:id))
end
```

### Authorization Test Cases

```elixir
test "user can update their own display_name" do
  user = create_user!()

  assert {:ok, updated_user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "New Name"
    }, actor: user)
    |> Ash.update()

  assert updated_user.display_name == "New Name"
end

test "user cannot update another user's display_name" do
  user1 = create_user!(email: "user1@example.com")
  user2 = create_user!(email: "user2@example.com")

  assert {:error, %Ash.Error.Forbidden{}} =
    user1
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "Hacked Name"
    }, actor: user2)  # Wrong actor
    |> Ash.update()
end

test "unauthenticated request fails" do
  user = create_user!()

  assert {:error, %Ash.Error.Forbidden{}} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "New Name"
    })  # No actor
    |> Ash.update()
end
```

## Test Contract

### Required Test Cases

#### Happy Path Tests

```elixir
test "updates display_name successfully" do
  user = create_user!(display_name: "Old Name")

  assert {:ok, updated_user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "New Name"
    }, actor: user)
    |> Ash.update()

  assert updated_user.display_name == "New Name"
end

test "updates to single-name display_name" do
  user = create_user!(display_name: "John Doe")

  assert {:ok, updated_user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "Cher"
    }, actor: user)
    |> Ash.update()

  assert updated_user.display_name == "Cher"
end

test "updates to display_name with emoji" do
  user = create_user!(display_name: "Alex")

  assert {:ok, updated_user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "Alex 🚀"
    }, actor: user)
    |> Ash.update()

  assert updated_user.display_name == "Alex 🚀"
end

test "updates to display_name at maximum length (70 chars)" do
  user = create_user!(display_name: "Short")
  long_name = String.duplicate("A", 70)

  assert {:ok, updated_user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: long_name
    }, actor: user)
    |> Ash.update()

  assert updated_user.display_name == long_name
end
```

#### Validation Failure Tests

```elixir
test "rejects empty display_name" do
  user = create_user!(display_name: "Original Name")

  assert {:error, %Ash.Error.Invalid{}} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: ""
    }, actor: user)
    |> Ash.update()

  # Verify original name unchanged
  assert Ash.get!(User, user.id).display_name == "Original Name"
end

test "rejects display_name over 70 characters" do
  user = create_user!(display_name: "Original Name")
  long_name = String.duplicate("A", 71)

  assert {:error, %Ash.Error.Invalid{}} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: long_name
    }, actor: user)
    |> Ash.update()

  # Verify original name unchanged
  assert Ash.get!(User, user.id).display_name == "Original Name"
end

test "rejects nil display_name" do
  user = create_user!(display_name: "Original Name")

  assert {:error, %Ash.Error.Invalid{}} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: nil
    }, actor: user)
    |> Ash.update()
end
```

#### Edge Case Tests

```elixir
test "allows duplicate display_names across users" do
  user1 = create_user!(email: "user1@example.com", display_name: "John Doe")
  user2 = create_user!(email: "user2@example.com", display_name: "Jane Doe")

  # Update user2 to have same name as user1
  assert {:ok, updated_user2} =
    user2
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "John Doe"
    }, actor: user2)
    |> Ash.update()

  assert updated_user2.display_name == "John Doe"
  assert Ash.get!(User, user1.id).display_name == "John Doe"
end

test "allows changing display_name multiple times" do
  user = create_user!(display_name: "Name 1")

  {:ok, user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "Name 2"
    }, actor: user)
    |> Ash.update()

  assert user.display_name == "Name 2"

  {:ok, user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "Name 3"
    }, actor: user)
    |> Ash.update()

  assert user.display_name == "Name 3"
end

test "updates timestamp when display_name changes" do
  user = create_user!(display_name: "Original")
  original_timestamp = user.updated_at

  # Wait a moment to ensure timestamp difference
  :timer.sleep(10)

  {:ok, updated_user} =
    user
    |> Ash.Changeset.for_update(:update_display_name, %{
      display_name: "Updated"
    }, actor: user)
    |> Ash.update()

  assert DateTime.compare(updated_user.updated_at, original_timestamp) == :gt
end
```

## Integration Points

### Phoenix LiveView

Typically called from a profile settings page:
```elixir
def handle_event("update_name", %{"display_name" => new_name}, socket) do
  case socket.assigns.current_user
       |> Ash.Changeset.for_update(:update_display_name, %{
         display_name: new_name
       }, actor: socket.assigns.current_user)
       |> Ash.update() do
    {:ok, updated_user} ->
      {:noreply,
       socket
       |> assign(:current_user, updated_user)
       |> put_flash(:info, "Display name updated successfully")}

    {:error, error} ->
      {:noreply, put_flash(socket, :error, "Failed to update display name")}
  end
end
```

### GraphQL (if applicable)

```graphql
mutation UpdateDisplayName($displayName: String!) {
  updateDisplayName(displayName: $displayName) {
    id
    displayName
    updatedAt
  }
}
```

## Changes from Previous Version

**Before**:
- Max length was 30 characters
- Validation: `string_length(:display_name, min: 1, max: 30)`

**After**:
- Max length is 70 characters
- Validation: `string_length(:display_name, min: 1, max: 70)`

All other behavior remains the same.
