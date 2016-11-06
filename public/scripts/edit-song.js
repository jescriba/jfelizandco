$(window).load(function() {
  var song = $.parseJSON($("#json-data").html());
  $(".fa.fa-plus").click(function(event) {
    var date = new Date();
    var time = date.getTime().toString();
    $("#additional-artists").append("<input type='input' name='artist" + time + "' placeholder='Another artist'></input><br>")
  });
  $("#delete").click(function(event) {
    $("#delete").append("<div id='confirm'>are you sure?</div>");
    $("#confirm").click(function() {
      $.ajax({
        url: '/songs/' + song.id + "/delete",
        type: 'DELETE',
        success: function(result) {
          window.location.replace("/songs");
        }
      });
    });
  });
});
