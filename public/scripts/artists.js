$(window).on("load", function() {
  var artists = $.parseJSON($("#json-data").html());
  $(".artist-link").click(function(event) {
    window.location.href =  "/artists/" + event.currentTarget.id + "/songs" ;
  });
});
