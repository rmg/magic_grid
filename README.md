MagicGrid
=========

Takes a collection (ActiveRecord or Array) and creates a paginated table of
it using a supplied column definition. It can generate the rows for you, or
you can supply a block to do it yourself.

Basic Usage
-----------

In your `Gemfile`:

    gem 'magic_grid'

In your view:

    <%= magic_grid(@posts, [:title, :author]) %>

Or a more realistic example:

```ruby
<%= magic_grid(@posts, [:title, :author, "Actions"]) do |post| %>
  <tr>
    <td><%= link_to(post.title, post) %></td>
    <td><%= link_to(post.author, post.author) %></td>
    <td>
      <%= link_to("Edit", edit_post_path(post)) %> |
      <%= link_to("Delete", post, method: :delete,
                  data: {confirm: "Are you sure?"}) %>
    </td>
  </tr>
<% end %>
```

Development
-----------

Testing was originally done UnitTest style, with some tarantula to force a
bunch of random page renderings. I've since added some RSpec goodness.

To run all the tests, just run +rake+.

