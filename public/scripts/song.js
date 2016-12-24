var currentSong;

$(window).on("load", function() {
  var isEditing = false;
  var songs= $.parseJSON($("#json-data").html());
  debugger;
  updateSongDetails(songs[0]);
  updatePlayingState();
  $("#forward").hide();
  $("#backward").hide();
  
  $("#play").click(function(event) {
    startPlaying();
  });
  $("#pause").click(function(event) {
    stopPlaying();
  });
  $(".download").click(function(event) {
    event.preventDefault();
    window.location.href = currentSong.url;
  });
  $(".share").click(function(event) {
    // TODO
  });
  $("audio").on("ended", function() {
    updatePlayingState();
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
      var id = event.currentTarget.id;
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
  currentSong = song;
  $("audio").attr("src", song.url);
  $("#song-name").text(song.name);
}
