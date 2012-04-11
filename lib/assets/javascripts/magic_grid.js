// vim: ts=4 et sw=4 sts=4

$(function () {
    // Micro-plugin for positioning the cursor
    $.fn.setCursor = $.fn.setCursor || function(pos) {
        return this.each(function() {
            if (this.setSelectionRange) {
                this.focus();
                this.setSelectionRange(pos, pos);
            } else if (this.createTextRange) {
                var range = this.createTextRange();
                range.collapse(true);
                range.moveEnd('character', pos);
                range.moveStart('character', pos);
                range.select();
            }
        });
    };

    // Micro-plugin for getting the position of the cursor
    $.fn.getCursor = $.fn.getCursor || function () {
        // IE doesn't have selectionStart, and I'm too lazy to implement
        // the IE specific version of this, so we'll just assume
        // the cursor is at the end of the input for this case.
        if (typeof this[0].selectionStart === 'undefined') {
            return this.value.length;
        } else {
            return this[0].selectionStart;
        }
    };

    // Micro-plugin for collecting all the listener and search inputs
    $.fn.getGridParams = $.fn.getGridParams || function (extras) {
        var listeners = this.data("listeners"),
            params = $.extend({}, {'magic_grid_id' : this.attr('id')}, extras || {}),
            $input, param_key, listened_id;
        for (listened_id in listeners) {
            param_key = listeners[listened_id];
            $input = $("#" + listened_id);
            if ($input.is(":checkbox")) {
                params[param_key] = $input.is(":checked");
            } else if ($input.is("select")) {
                params[param_key] = $input.find("option:selected").val();
            } else {
                params[param_key] = $input.val();
            }
        }
        if (this.is("[data-searcher]")) {
            params[this.attr('id') + '_q'] = $("#" + this.data("searcher")).val();
        }
        return $.extend({}, params);
    }

    // Default handler for ajax events that displays 'Loading...' in
    // the head of the table.
    $(".magic_grid[data-default-ajax-handler=true]").on("magic_grid:loading", function (e) {
        $(".magic_grid_spinner", this).
            addClass("ui-icon-spinner").
                html("<em>Loading...</em>");
    });

    $(".magic_grid[data-remote=true]").on( "click", ".pagination a, .sorter a", function (e) {
        var $grid = $(e.delegateTarget),
            url = this.href;
        $grid.trigger("magic_grid:loading");
        $grid.load(url + ' #' + $grid.attr('id') + " > *", function () {
            $grid.trigger("magic_grid:loaded");
        });
        return false;
    });

    $(".magic_grid[data-searcher]").each( function () {
        var $grid = $(this),
            grid_id = this.id,
            input_id = "#" + $grid.data("searcher"),
            live = $grid.data("live-search"),
            // keydown seems to be the only reliable and portable way to capture
            // things like backspace and delete
            events = (live ? "keydown change search" : "change search"),
            timer = null,
            internal = ($grid.has(input_id).length > 0),
            listener = (internal ? $grid : $(input_id).parent()),
            minLength = $(input_id).data("min-length") || 3;
        listener.on(events, input_id, function (e) {
            var is_manual = (e.type == 'search' ||
                             e.type == 'change' ||
                             (e.type == 'keydown' && e.which == '13')),
                base_url = $grid.data("current") || "",
                //40 wpm typists == 280ms/keystroke
                //90 wpm typists == 120ms/keystroke
                delay = is_manual ? 1 : (parseInt(live) || 500);
            clearTimeout(timer);
            timer = setTimeout(function () {
                var $input = $(input_id),
                    current = $input.data("current"),
                    value = $input.val(),
                    length = value.length,
                    url = base_url + "?",
                    relevant = is_manual || (value != current && (length >= minLength || length == 0)),
                    pos = $input.getCursor();
                clearTimeout(timer);
                url += $.param($grid.getGridParams());
                if (relevant) {
                    $grid.trigger("magic_grid:loading");
                    if ($grid.data("remote")) {
                        if (internal && live && !is_manual) {
                            $(input_id).prop('disabled', true);
                        }
                        $grid.load(url + ' #' + grid_id + ' > *', function () {
                            // Move the cursor back to where it was,
                            // less surprising that way.
                            // EXCEPT FOR IE, that is
                            $grid.trigger("magic_grid:loaded");
                            if (internal) {
                                $(input_id).setCursor(pos);
                            }
                        });
                    } else {
                        window.location = url;
                    }
                }
            }, delay);
        });
    });

    $(".magic_grid[data-listeners]").each( function () {
        var $grid = $(this),
            listeners = $grid.data("listeners"),
            grid_id = this.id
            base_url = $grid.data("current"),
            handler = function (change) {
                var url = base_url + "?" + $.param($grid.getGridParams());
                $grid.trigger("magic_grid:loading");
                if ($grid.data("remote")) {
                    $grid.load(url + ' #' + grid_id + " > *", function () {
                        $grid.trigger("magic_grid:loaded");
                    });
                } else {
                    window.location = url;
                }
            };
        for (var k in listeners) {
            if ($("#" + k).hasClass("ready")) {
                $("#" + k).on("change", {"field": listeners[k]}, handler);
            } else {
                $("#" + k).on("ready", {"field": listeners[k]}, function (ready) {
                    $(this).on("change", ready.data, handler);
                });
            }
        }
    });

    $(".magic_grid").trigger("magic_grid:loaded");
});
