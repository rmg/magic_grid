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
    $(".magic_grid[data-default-ajax-handler=true]").on("magic_grid:loading", function (e) {
        $(".magic_grid_spinner", this).
            addClass("ui-icon-spinner").
                html("<em>Loading...</em>");
    });
    $(".magic_grid[data-remote=true]").on( "click", ".pagination a, .sorter a", function (e) {
        var $grid = $(e.delegateTarget),
            url = this.href;
        $grid.trigger("magic_grid:loading");
        $grid.load(url + ' #' + $grid.attr('id') + " > *");
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
            minLength = $(input_id).data("min-length") || 3;
        $grid.on(events, input_id, function (e) {
            var is_manual = (e.type == 'search' ||
                             e.type == 'change' ||
                             (e.type == 'keydown' && e.which == '13')
                            ),
                base_url = $grid.data("current") || "",
                params = {'magic_grid_id' : grid_id},
                //40 wpm typists == 280ms/keystroke
                //90 wpm typists == 120ms/keystroke
                delay = is_manual ? 1 : 500;
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
                params[grid_id + "_q"] = value;
                url += $.param(params);
                if (relevant) {
                    $grid.trigger("magic_grid:loading");
                    if ($grid.data("remote")) {
                        $(input_id).prop('disabled', true);
                        $grid.load(url + ' #' + grid_id + ' > *', function () {
                            // Move the cursor back to where it was,
                            // less surprising that way.
                            // EXCEPT FOR IE, that is
                            $(input_id).setCursor(pos);
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
            get_values = function () {
                var $input, key, params = {};
                for (var k in listeners) {
                    key = listeners[k];
                    $input = $("#" + k);
                    if ($input.is(":checkbox")) {
                        params[key] = $input.is(":checked");
                    } else if ($input.is("select")) {
                        params[key] = $input.find("option:selected").val();
                    } else {
                        params[key] = $input.val();
                    }
                }
                return params;
            },
            handler = function (change) {
                var url = base_url + "?" + $.param(get_values());
                $grid.trigger("magic_grid:loading");
                if ($grid.data("remote")) {
                    $grid.load(url + ' #' + grid_id + " > *");
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
});
