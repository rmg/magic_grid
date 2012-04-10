// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
$(function () {
    $("#user_id").addClass("ready");
    $(".magic_grid").on("magic_grid:loaded", function () {
        console.log("Loaded a grid: ", this);
    });
});
