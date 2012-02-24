$(function () {
    $(".ajaxed_pager").on( "click", ".pagination a, .sorter a", function (e) {
        var $a = $(this),
            $container = $a.closest(".ajaxed_pager"),
            url = $a.attr('href');
        $a.addClass("ui-icon-spinner");
        $container.load(url + ' #' + $container.attr('id') + " > *");
        return false;
    });
    $(".has-searcher").each( function () {
        var $grid = $(this),
            grid_id = this.id,
            input_id = "#" + $grid.data("searcher"),
            live = $grid.data("live-search"),
            events = (live ? "keyup search change" : "search change"),
            timer = null;
        $grid.parent().on(events, input_id, function (e) {
            var minLength = $(input_id).data("min-length") || 3,
                length = this.value.length,
                is_manual = (e.type == 'search' || e.type == 'change'),
                relevant =  is_manual || length >= minLength || length == 0,
                base_url = $grid.data("current"),
                params = {},
                //40 wpm typists == 280ms
                //90 wpm typists == 120ms
                delay = is_manual ? 0 : 250;
            if (relevant) {
                clearTimeout(timer);
                timer = setTimeout(function () {
                    var value = $(input_id).val()
                        url = base_url + "?";
                    params[grid_id + "_q"] = value;
                    url += $.param(params);
                    if ($grid.hasClass("ajaxed_pager")) {
                        $grid.load(url + ' #' + grid_id + ' > *', function () {
                            if (e.type == 'keyup') {
                                $(input_id).focus()[0].setSelectionRange(value.length, value.length);
                            }
                        });
                    } else {
                        window.location = url;
                    }
                }, delay);
            }
        });
    });
    $(".has-listeners").each( function () {
        var $grid = $(this),
            listeners = $grid.data("listeners"),
            grid_id = this.id
            base_url = $grid.data("current");
        for (var k in listeners) {
            $("#" + k).on("change", {"field": listeners[k]}, function (e) {
                var params = {},
                    key = /* grid_id + "_" + */ e.data.field,
                    value = this.value,
                    url = base_url + "?";
                params[key] = value;
                url += $.param(params);
                if ($grid.hasClass("ajaxed_pager")) {
                    $grid.load(url + ' #' + grid_id + " > *");
                } else {
                    window.location = url;
                }
            });
        }
    });
});
