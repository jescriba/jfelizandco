$(window).load(function() {
  var artists = $.parseJSON($("#json-data").html());
  $(".btn").click(function(event) {
    window.location.href =  "/artists/" + event.target.id + "/songs" ;
  });
  $(".fa.fa-search").click(function(event) {
    window.location.href = "/search";
  });
});
