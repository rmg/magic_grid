$(function () {
    $(".ajaxed_pager").on( "click", ".pagination a", function (e) {
        var $a = $(this),
            $container = $a.closest(".ajaxed_pager"),
            url = $a.attr('href');
        $a.addClass("ui-icon-spinner");
        $container.load(url + ' #' + $container.attr('id') + " > *");
        return false;
    });
});
