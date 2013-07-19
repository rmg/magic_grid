MagicGrid
=========
&copy; 2011-2013 Ryan Graham, Dennis Taylor

[![Gem Version](https://badge.fury.io/rb/magic_grid.png)](http://badge.fury.io/rb/magic_grid)
[![Build Status](https://travis-ci.org/rmg/magic_grid.png?branch=master)](https://travis-ci.org/rmg/magic_grid)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/rmg/magic_grid)

Easy collection display grid with column sorting and pagination.

[MagicGrid Live Demo](http://magic-grid.herokuapp.com/) (it's not very pretty. [Help?](https://github.com/rmg/magic_grid-demo))

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

In your controller:

    @posts = Post.where(:published => true)

In your view:

    <%= magic_grid(@posts, [:title, :author]) %>

What you'll get is an table with 2 sortable columns. You'll also get pagination if
you have eitehr Keminari or WillPaginate loaded.

You can also do your own row rendering by passing a block:

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

Advanced Options
----------------

There are a bunch of extra options that can be passed to the `magic_grid` helper:

### :searchable
An array of columns to try to generate a search query for. Providing this
list tells magic_grid to render a search box in the header of the html table
it generates. Make sure to include `magic_grid.js` in your view or application wide via your application.js or search won't work.

### :per_page
Sets the number of rows per page in the paginator.

### :title
Sets a text string to include in the top of the grid's `thead` to display as a title for the grid.

### and more...
There's a.. *ahem* slight lack of documentation at the moment. Pull requests welcome?

Development
-----------

Testing was originally done UnitTest style, with some tarantula to force a
bunch of random page renderings. I've since added some RSpec goodness.

To run all the tests, just run `rake`.

License
-------

Distributed under the MIT license. See [MIT-LICENSE](MIT-LICENSE) for detail.
