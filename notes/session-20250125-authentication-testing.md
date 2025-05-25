# Authentication Testing with Wallaby - Important Learning

## Key Discovery

When testing authentication flows with Wallaby, we must use the actual email-based magic link flow, not generate tokens directly. This ensures proper session establishment that persists across page navigations.

## Working Approach (from sign_in_and_sign_out_steps_test.exs)

```elixir
defstep "the user clicks the magic link in their email", context do
  # Get the magic link token from the email
  receive do
    {:email, %{to: [{_, email}], assigns: %{url: url}}} when email == context.email ->
      # Extract token from URL and visit the magic link
      session = context.session |> visit(url)
      {:ok, Map.put(context, :session, session)}
  after
    1000 ->
      raise "No email received"
  end
end
```

## Failed Approach (don't do this)

```elixir
# This doesn't establish proper session!
strategy = Info.strategy!(Huddlz.Accounts.User, :magic_link)
{:ok, token} = MagicLink.request_token_for(strategy, user)
magic_link_url = "/auth/user/magic_link?token=#{token}"
session = session |> visit(magic_link_url)
```

## Complete Authentication Flow for Tests

1. Visit sign-in page
2. Fill in email and click "Request magic link"
3. Wait for confirmation message
4. Extract URL from email using `receive` block
5. Visit the URL from the email
6. Verify "You are now signed in" message

## Shared Step Implementation

When creating shared authentication steps across multiple test files:

```elixir
defstep "I am signed in as {string}", %{session: session, args: args} = context do
  email = List.first(args)
  
  # Full flow through UI
  session = visit(session, "/sign-in")
  session = 
    session
    |> fill_in(text_field("Email"), with: email)
    |> click(button("Request magic link"))
  
  assert_has(session, css("[role='alert']", text: "you will be contacted"))
  
  # Get actual email
  receive do
    {:email, %{to: [{_, to}], assigns: %{url: url}}} when to == email ->
      session = visit(session, url)
      assert_has(session, css("[role='alert']", text: "You are now signed in"))
      {:ok, Map.merge(context, %{session: session, current_user: user})}
  after
    5000 -> raise "No email received"
  end
end
```

## Why This Matters

- Direct token generation bypasses proper session establishment
- The email flow ensures cookies are properly set
- Session persists across page navigations only with proper flow
- This mimics actual user behavior more accurately

## Action Items

1. Update all authentication steps to use email-based flow
2. Create a shared authentication helper module
3. Ensure all test files use consistent approach
4. Document this in testing guidelines