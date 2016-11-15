$(window).load(function() {
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
    updateSongDetails(song);
    updatePlayingState();
  });
  $("#play").click(function(event) {
    startPlaying();
  });
  $("#pause").click(function(event) {
    stopPlaying();
  });
  $("audio").on("ended", function() {
    updateSongDetails(nextSong());
  });
  $("audio").on("play", function() {
    updatePlayingState();
  });
  $("audio").on("pause", function() {
    updatePlayingState();
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

function isPlaying() {
  return !$("audio").get(0).paused;
}

function updatePlayingState() {
  if (isPlaying()) {
    $("#play").hide();
    $("#pause").show();
  } else {
    $("#play").show();
    $("#pause").hide();
  }
}

function startPlaying() {
  $("audio").get(0).play();
}

function stopPlaying() {
  $("audio").get(0).pause();
}

function updateSongDetails(song) {
  $(".song-details").hide();
  $("p#" + song.id + ".song-details").show();
  $("audio").attr("src", song.url);
  $("#song-name").text(song.name);
}
