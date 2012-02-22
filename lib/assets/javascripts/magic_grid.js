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
            $input = $("#" + $grid.data("searcher")),
            minLength = $input.data("minLength") || 3;
        $input.on("keyup", function () {
            if (this.value.length >= minLength) {
                var id = $grid.attr('id'),
                    params = {},
                    base_url = $grid.data("current");
                params[id + "_q"] = this.value;
                $grid.load(base_url + "?" + $.param(params) +
                           ' #' + id + ' > *');
            }
        });
    });
});
