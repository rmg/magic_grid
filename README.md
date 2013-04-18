MagicGrid
=========
&copy; 2011-2013 Ryan Graham, Dennis Taylor

[![Build Status](https://travis-ci.org/rmg/magic_grid.png?branch=master)](https://travis-ci.org/rmg/magic_grid)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/rmg/magic_grid)


Easy collection display grid with column sorting and pagination.

Displays a collection (ActiveRelation or Array) wrapped in an html table with server
side column sorting, filtering hooks, and search bar. Large collections can be
paginated with either the will_paginate gem or kaminari gem if you use them, or a naive
Enumerable based paginator (without pager links) if neither is present.

Tables are styled using Themeroller compatible classes, which also don't look _too_ bad
with Bootstrap.

Basic Usage
-----------

In your `Gemfile`:

    gem 'magic_grid'

In your view:

    <%= magic_grid(@posts, [:title, :author]) %>

Or a more realistic example:

```rhtml
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

To run all the tests, just run `rake`.

License
-------

Distributed under the MIT license. See [MIT-LICENSE](MIT-LICENSE) for detail.
