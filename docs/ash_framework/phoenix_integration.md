# Ash Framework: Phoenix Integration

This document covers how to integrate Ash Framework with Phoenix for web interfaces, including controllers, LiveView, forms, and real-time features.

## Table of Contents

- [Using Ash in Phoenix Controllers](#using-ash-in-phoenix-controllers)
  - [Retrieving and Displaying Data](#retrieving-and-displaying-data-from-ash-resources)
  - [Using Aggregates](#using-aggregates-in-ash)
  - [Integration Patterns](#integration-patterns)
- [CRUD Operations with LiveView](#crud-operations-with-ash-and-phoenix-liveview)
  - [Setup for LiveView](#setup-for-liveview-development)
  - [Resource Routes](#resource-routes-for-crud-operations)
  - [Reading Records](#reading-records-with-liveview)
  - [Creating Records](#creating-records-with-ashphoenixform)
  - [Updating Records](#updating-records-with-ashphoenixform)
  - [CRUD Workflow Summary](#crud-workflow-summary)
- [Real-Time Features](#real-time-features-with-ashnotifications)
  - [Configuration](#configuration)
  - [Setting Up Resource Notifications](#setting-up-resource-notifications)

## Using Ash in Phoenix Controllers

Phoenix handles the user interface layer while Ash manages the domain logic, business processes, and backend functionality. Here's how to use them together:

### Retrieving and Displaying Data from Ash Resources

To display categories and their articles on a Phoenix page:

1. In your controller, retrieve data from Ash resources and pass it to the view:

```elixir
# In PageController
defmodule HelpcenterWeb.PageController do
  alias Helpcenter.KnowledgeBase.Category
  use HelpcenterWeb, :controller

  def home(conn, _params) do
    # Retrieve categories with their articles
    categories = Ash.read!(Category, load: :articles)

    # Pass data to the view
    render(conn, :home, layout: false, categories: categories)
  end
end
```

2. In your template (.heex file), display the data using Phoenix templating:

```html
<!-- List categories and display their article count -->
<a
  :for={category <- @categories}
  href="#"
  class="block rounded-md hover:border p-5 shadow transition hover:shadow-md"
>
  <div class="mb-3 flex items-center">
    <svg class="h-6 w-6 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
      <path d="M4 3h12v2H4V3zm0 3h12v2H4V6zm0 3h10v2H4V9zm0 3h8v2H4v-2z" />
    </svg>
    <h2 class="ml-2 text-lg font-medium text-gray-800">{category.name}</h2>
  </div>
  <p class="text-sm text-gray-600">{category.description}</p>

  <!-- Count articles under each category  -->
  <p class="mt-2 text-xs text-gray-500">{Enum.count(category.articles)} articles</p>
</a>
```

This approach loads all articles and counts them in the view layer, which is inefficient for large datasets.

### Using Aggregates in Ash

Aggregates help optimize data retrieval by grouping and summarizing related data at the database level. They're particularly useful for operations like count, sum, average, etc.

#### Defining Aggregates

Add an aggregate to your resource to count related records:

```elixir
# In the Category resource
aggregates do
  count :article_count, :articles
end
```

This defines an `article_count` aggregate that counts all articles related to each category.

#### Using Aggregates in Controllers

Update your controller to use the aggregate instead of loading all related records:

```elixir
# In PageController
def home(conn, _params) do
  # Use the aggregate instead of loading all articles
  categories = Ash.read!(Category, load: :article_count)
  
  render(conn, :home, layout: false, categories: categories)
end
```

#### Display Aggregate Values in Views

Update your template to use the aggregate value:

```html
<!-- Before: Using Enum.count on loaded articles -->
<p class="mt-2 text-xs text-gray-500">{Enum.count(category.articles)} articles</p>

<!-- After: Using the pre-computed aggregate -->
<p class="mt-2 text-xs text-gray-500">{category.article_count} articles</p>
```

#### Benefits of Aggregates

1. **Performance**: Calculates aggregations at the database level rather than in application memory
2. **Reduced Data Transfer**: Only transfers the aggregate value rather than all related records
3. **Optimized Queries**: Database can use optimized query plans for aggregations
4. **Cleaner Code**: Separates data analytics from presentation logic

### Types of Aggregates in Ash

Ash supports various types of aggregates:

- `count`: Count related records
- `sum`: Sum a field across related records
- `avg`: Calculate average of a field
- `min`: Find minimum value
- `max`: Find maximum value
- `list`: Create a list of values
- `first`: Get first related record
- `custom`: Define custom aggregation logic

### Integration Patterns

When integrating Ash with Phoenix:

1. **Keep Domain Logic in Resources**: All business rules, validations, and data manipulations should be in Ash resources
2. **Use Controllers as Coordinators**: Controllers should coordinate between Ash and Phoenix, not contain business logic
3. **Optimize Data Retrieval**: Use aggregates and selective loading with `load:` to minimize data transfer
4. **Favor Domain-Driven Design**: Structure your Phoenix UI around the domain concepts defined in Ash

## CRUD Operations with Ash and Phoenix LiveView

This section covers how to implement Create, Read, Update, and Delete (CRUD) operations using Ash with Phoenix LiveView and the AshPhoenix package.

### Setup for LiveView Development

#### LiveView Callback Helper Functions

Adding concise helper functions to reduce repetition in LiveView callbacks:

```elixir
# In lib/helpcenter_web.ex (html_helpers section)
# LiveView and live components callbacks helpers
def ok(socket), do: {:ok, socket}
def halt(socket), do: {:halt, socket}
def continue(socket), do: {:cont, socket}
def noreply(socket), do: {:noreply, socket}
```

These helpers simplify common LiveView callback returns, allowing you to write `ok(socket)` instead of `{:ok, socket}`.

### Resource Routes for CRUD Operations

Structure routes by resource domain for better organization:

```elixir
# In router.ex
scope "/", HelpcenterWeb do
  pipe_through :browser

  # Add categories route
  scope "/categories" do
    live "/", CategoriesLive             # List all categories
    live "/create", CreateCategoryLive   # Create new category 
    live "/:category_id", EditCategoryLive # Edit existing category
  end

  # Other routes...
end
```

### Reading Records with LiveView

Implementing a LiveView for listing categories:

```elixir
defmodule HelpcenterWeb.CategoriesLive do
  use HelpcenterWeb, :live_view

  def render(assigns) do
   ~H"""
    <%!-- New Category Button --%>
    <.button id="create-category-button" phx-click={JS.navigate(~p"/categories/create")}>
      <.icon name="hero-plus-solid" />
    </.button>

    <%!-- List category records --%>
    <h1>{gettext("Categories")}</h1>

    <.table id="knowledge-base-categories" rows={@categories}>
      <:col :let={row} label={gettext("Name")}>{row.name}</:col>
      <:col :let={row} label={gettext("Description")}>{row.description}</:col>
      <:action :let={row}>
        <%!-- Edit Category button --%>
        <.button
          id={"edit-button-#{row.id}"}
          phx-click={JS.navigate(~p"/categories/#{row.id}")}
          class="bg-white text-zinc-500 hover:bg-white hover:text-zinc-900 hover:underline"
        >
          <.icon name="hero-pencil-solid" />
        </.button>

        <%!-- Delete Category Button --%>
        <.button
          id={"delete-button-#{row.id}"}
          phx-click={"delete-#{row.id}"}
          class="bg-white text-zinc-500 hover:bg-white hover:text-zinc-900"
        >
          <.icon name="hero-trash-solid" />
        </.button>
      </:action>
    </.table>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign_categories()
    |> ok()
  end

  # Handle delete button click
  def handle_event("delete-" <> category_id, _params, socket) do
    case destroy_record(category_id) do
      :ok ->
        socket
        |> put_flash(:info, "Category deleted successfully")
        |> noreply()

      {:error, _error} ->
        socket
        |> put_flash(:error, "Unable to delete category")
        |> noreply()
    end
  end

  defp assign_categories(socket) do
    {:ok, categories} =
      Helpcenter.KnowledgeBase.Category
      |> Ash.read()

    assign(socket, :categories, categories)
  end

  defp destroy_record(category_id) do
    Helpcenter.KnowledgeBase.Category
    |> Ash.get!(category_id)
    |> Ash.destroy()
  end
end
```

This LiveView:
- Lists all categories from the database
- Provides buttons to edit or delete each category
- Has a button to create a new category
- Handles category deletion with immediate feedback

### Creating Records with AshPhoenix.Form

AshPhoenix provides form handling utilities to simplify the create/update process with real-time validation:

```elixir
defmodule HelpcenterWeb.CreateCategoryLive do
  use HelpcenterWeb, :live_view
  alias AshPhoenix.Form

  def render(assigns) do
   ~H"""
    <%!-- Back button --%>
    <.back navigate={~p"/categories"}>{gettext("Back to categories")}</.back>

    <%!-- Category form --%>
    <.simple_form for={@form} id="category-form" phx-submit="save" phx-change="validate">
      <h1>{gettext("New Category")}</h1>
      <.input field={@form[:name]} label={gettext("Name")} />
      <.input field={@form[:description]} label={gettext("Desription")} type="textarea" />

      <:actions>
        <.button>{gettext("Submit")}</.button>
      </:actions>
    </.simple_form>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign_form()
    |> ok()
  end

  # Real-time validation handler
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)

    socket
    |> assign(:form, form)
    |> noreply()
  end

  # Form submission handler
  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, category} ->
        socket
        |> put_flash(:info, "Category '#{category.name}' created!")
        |> redirect(to: ~p"/categories")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> put_flash(:error, "Unable to create category")
        |> noreply()
    end
  end

  # Create the initial form
  defp assign_form(socket) do
    form =
      Helpcenter.KnowledgeBase.Category
      |> Form.for_create(:create)
      |> to_form()

    assign(socket, :form, form)
  end
end
```

Key components:
- `AshPhoenix.Form` handles form state and validation
- `Form.for_create(:create)` creates a form for the create action
- `Form.validate` performs real-time validation as the user types
- `Form.submit` handles final validation and database insertion
- `to_form()` converts the Ash form to a compatible Phoenix form

### Updating Records with AshPhoenix.Form

Implementing record updates follows a similar pattern:

```elixir
defmodule HelpcenterWeb.EditCategoryLive do
  use HelpcenterWeb, :live_view
  alias AshPhoenix.Form

  def render(assigns) do
   ~H"""
    <%!-- Back button --%>
    <.back navigate={~p"/categories"}>{gettext("Back to categories")}</.back>

    <%!-- Edit form --%>
    <.simple_form
      for={@form}
      id={"category-form-#{@category_id}"}
      phx-submit="save"
      phx-change="validate"
    >
      <h1>{gettext("New Category")}</h1>
      <.input field={@form[:name]} label={gettext("Name")} />
      <.input field={@form[:description]} label={gettext("Desription")} type="textarea" />

      <:actions>
        <.button>{gettext("Submit")}</.button>
      </:actions>
    </.simple_form>
    """
  end

  def mount(%{"category_id" => id} = _params, _session, socket) do
    socket
    |> assign(:category_id, id)
    |> assign_form()
    |> ok()
  end

  # Real-time validation
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)

    socket
    |> assign(:form, form)
    |> noreply()
  end

  # Form submission
  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, category} ->
        socket
        |> put_flash(:info, "Category '#{category.name}' created!")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> put_flash(:error, "Unable to create category")
        |> noreply()
    end
  end

  # Create form for updating existing record
  defp assign_form(socket) do
    form =
      Helpcenter.KnowledgeBase.Category
      |> Ash.get!(socket.assigns.category_id)
      |> Form.for_update(:update)
      |> to_form()

    assign(socket, :form, form)
  end
end
```

Key differences from create:
- Takes a `category_id` parameter from the URL
- Uses `Ash.get!` to retrieve the existing record
- Uses `Form.for_update(:update)` instead of `Form.for_create(:create)`

### Key Benefits of AshPhoenix.Form

1. **Real-time Validation**: Validates form input as users type
2. **Automatic Error Handling**: Displays validation errors from Ash resources
3. **Simplified Form Management**: Handles form state and submission
4. **Action Integration**: Directly connects forms to Ash resource actions
5. **Type Safety**: Leverages Ash's type system for form fields

### CRUD Workflow Summary

1. **Create**:
   - Define create action in Ash resource
   - Use `Form.for_create(:create)` to generate form
   - Submit with `Form.submit`

2. **Read**:
   - Use `Ash.read()` or `Ash.read!()` to fetch records
   - Assign records to socket for display

3. **Update**:
   - Retrieve record with `Ash.get!`
   - Create update form with `Form.for_update(:update)`
   - Submit changes with `Form.submit`

4. **Delete**:
   - Retrieve record with `Ash.get!`
   - Use `Ash.destroy()` to remove the record

## Real-Time Features with Ash.Notifications

This section covers how to implement real-time functionality using Ash Notifications and Phoenix PubSub.

### Overview

Ash.Notifications allows resources to broadcast events when changes occur (create, update, destroy). Phoenix LiveView can listen for these events and update the UI in real-time without page refreshes.

### Configuration

First, enable debugging for Ash PubSub in your configuration:

```elixir
# In config/config.exs
config :ash, :pub_sub, debug?: true
```

This helps troubleshoot by showing PubSub notifications in the console logs.

### Setting Up Resource Notifications

1. Add the PubSub notifier to your resource:

```elixir
defmodule Helpcenter.KnowledgeBase.Category do
  use Ash.Resource,
    domain: Helpcenter.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    # Tell Ash to broadcast events via PubSub
    notifiers: Ash.Notifier.PubSub

  # The rest of the resource definition...
end
```

2. Configure PubSub settings for the resource:

```elixir
# Inside your resource module
pub_sub do
  # Use your Phoenix endpoint for publishing events
  module HelpcenterWeb.Endpoint

  # Set a prefix for all events from this resource
  # This allows targeted subscriptions in LiveView
  prefix "categories"
  
  # Define which events to publish and how to format their topics
  # This will publish events with topics like:
  #   "categories"
  #   "categories:UUID-PRIMARY-KEY-ID-OF-CATEGORY"
  publish_all :update, [[:id, nil]]
  publish_all :create, [[:id, nil]]
  publish_all :destroy, [[:id, nil]]
end
```

The `publish_all` function takes:
- First parameter: The action type (:create, :update, :destroy)
- Second parameter: A list of topic formats to publish

In the example above, `[[:id, nil]]` means:
- Publish to a topic with just the resource ID
- Also publish to a topic with no specific ID (general resource events)

This enables both general subscriptions (all categories) and specific subscriptions (single category).

### Subscribing to Notifications in LiveView

Update your LiveView to subscribe to PubSub events:

```elixir
defmodule HelpcenterWeb.CategoriesLive do
  use HelpcenterWeb, :live_view
  alias Helpcenter.KnowledgeBase.Category
  
  def mount(_params, _session, socket) do
    # Initial data load
    socket = assign_categories(socket)
    
    # Subscribe to all category events
    if connected?(socket) do
      topic = Ash.Notifier.PubSub.topic(Category)
      HelpcenterWeb.Endpoint.subscribe(topic)
    end
    
    {:ok, socket}
  end
  
  # Handle PubSub events for create
  def handle_info(%{topic: topic, event: %{action_type: :create}}, socket) do
    # Reload data when a category is created
    socket
    |> assign_categories()
    |> noreply()
  end
  
  # Handle PubSub events for update
  def handle_info(%{topic: topic, event: %{action_type: :update}}, socket) do
    # Reload data when a category is updated
    socket
    |> assign_categories()
    |> noreply()
  end
  
  # Handle PubSub events for destroy
  def handle_info(%{topic: topic, event: %{action_type: :destroy}}, socket) do
    # Reload data when a category is deleted
    socket
    |> assign_categories()
    |> noreply()
  end
  
  # Load categories from the database
  defp assign_categories(socket) do
    {:ok, categories} =
      Category
      |> Ash.read()
      
    assign(socket, :categories, categories)
  end
  
  # Rest of LiveView code...
end
```

Key points:
- `connected?(socket)` ensures we only subscribe on client-connected LiveViews
- `Ash.Notifier.PubSub.topic(Category)` generates the appropriate topic name
- `handle_info` callbacks process the different events
- Each event type (create, update, destroy) can be handled differently

### Optimizing Real-Time Updates

For better performance, you can:

1. **Subscribe to specific resources**: Subscribe only to the specific records you're displaying
2. **Smart reloading**: Instead of reloading all data, update only affected records
3. **Batch updates**: Debounce updates if multiple changes happen in quick succession

Example of optimized updating:

```elixir
def handle_info(%{topic: topic, event: %{action_type: :update, data: updated_category}}, socket) do
  # Update just the specific category in the list
  updated_categories = 
    socket.assigns.categories
    |> Enum.map(fn category ->
      if category.id == updated_category.id do
        updated_category
      else
        category
      end
    end)
    
  socket
  |> assign(:categories, updated_categories)
  |> noreply()
end
```

### Benefits of Real-Time Updates

1. **Improved User Experience**: Users see changes immediately without refreshing
2. **Consistency**: All connected clients have the same view of the data
3. **Reduced Server Load**: No need for polling or frequent full page refreshes
4. **Collaboration**: Enables multi-user collaborative features

### Practical Use Cases

1. **Admin Dashboards**: Updates appear for all admins without refreshing
2. **Collaborative Editing**: Changes from one user appear for others in real-time
3. **Status Monitoring**: System status updates appear immediately
4. **Chat Applications**: Messages appear instantly for all participants
5. **Interactive Forms**: Form validation happens as users type