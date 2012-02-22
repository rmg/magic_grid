$(function () {
    $(".ajaxed_pager").on( "click", ".pagination a", function (e) {
        var $a = $(this),
            $container = $a.closest(".ajaxed_pager"),
            url = $a.attr('href');
        $a.addClass("ui-icon-spinner");
        $container.load(url + ' #' + $container.attr('id') + " > *");
        return false;
    });
    $(".has-searcher.ajaxed_pager").each( function () {
        var $grid = $(this),
            grid_id = this.id,
            input_id = "#" + $grid.data("searcher"),
            live = $grid.data("live-search"),
            events = (live ? "keyup search" : "search"),
            timer = null;
        $grid.parent().on(events, input_id, function (e) {
            var minLength = $(input_id).data("minLength") || 3,
                length = this.value.length,
                relevant = !live || length >= minLength || length == 0,
                base_url = $grid.data("current"),
                params = {};
            console.log(e.type, this, arguments);
            if (relevant) {
                clearTimeout(timer);
                timer = setTimeout(function () {
                    var value = $(input_id).val();
                    params[grid_id + "_q"] = value;
                    $grid.load(base_url + "?" + $.param(params) +
                               ' #' + grid_id + ' > *', function () {
                        if (e.type == 'keyup') {
                            $(input_id).focus()[0].setSelectionRange(value.length, value.length);
                        }
                    });
                }, 250);
            }
        });
    });
});
