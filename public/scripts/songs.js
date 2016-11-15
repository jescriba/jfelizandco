$(window).load(function() {
  var isPlaying = false;
  var isEditing = false;
  var songs = $.parseJSON($("#json-data").html());
  var currentSongIndex = 0;
  
  function nextSong() {
    return songs[++currentSongIndex % songs.length];
  }

  $(".btn").click(function(event) {
    var song = "";
    var id = parseInt(event.target.id);
    for(var i = 0; i < songs.length; i++) {
      if(songs[i].id == id) {
        song = songs[i]
        currentSongIndex = i;
        break;
      }
    }
    if (isPlaying) {
      stopPlaying();
      isPlaying = false;
    }
    updateSongDetails(song);
  });
  $("#play").click(function(event) {
    startPlaying();
    isPlaying = true;
  });
  $("#pause").click(function(event) {
    stopPlaying();
    isPlaying = false;
  });
  $("audio").on("ended", function() {
    isPlaying = false;
    updateSongDetails(nextSong());
  });
  $("#edit").click(function(event) {
    if (isEditing) {
      $(".edit-song").hide();
      isEditing = false;
    } else {
      $(".edit-song").show();
      isEditing = true;
    }
    $(".edit-song").click(function(event) {
      var id = event.target.id;
      window.location.href = "/songs/" + id + "/edit"
    });
  });
});

function stopPlaying() {
  $("#pause").hide();
  $("#play").show();
  $("audio").get(0).pause();
}

function startPlaying() {
  $("#play").hide();
  $("#pause").show();
  $("audio").get(0).play();
}

function updateSongDetails(song) {
  $(".song-details").hide();
  $("p#" + song.id + ".song-details").show();
  $("#play").show();
  $("audio").attr("src", song.url);
  $("#song-name").text(song.name);
}
