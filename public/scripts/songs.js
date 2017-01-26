var currentSong;

$(window).on("load", function() {
  var isEditing = false;
  var songs = $.parseJSON($("#json-data").html());
  var currentSongIndex = 0;
  
  function nextSong() {
    return songs[++currentSongIndex % songs.length];
  }
  function lastSong() {
    return songs[--currentSongIndex % songs.length];
  }
  $(".song-link").click(function(event) {
    var song = "";
    var id = parseInt(event.currentTarget.id);
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
  $(".favorite").click(function(event) {
    // HACK: Seems like toggling classname doesn't update the event handler
    if(event.currentTarget.className == "fa fa-heart-o favorite") {
      favorite(event);
    } else {
      unfavorite(event);
    }
  });
  $(".unfavorite").click(function(event) {
    if(event.currentTarget.className == "fa fa-heart unfavorite") {
      unfavorite(event);
    } else {
      favorite(event);
    }
  });
  $("#play").click(function(event) {
    startPlaying();
  });
  $("#pause").click(function(event) {
    stopPlaying();
  });
  $("#forward").click(function(event) {
    updateSongDetails(nextSong());
  });
  $("#backward").click(function(event) {
    updateSongDetails(lastSong());
  });
  $(".download").click(function(event) {
    event.preventDefault();
    window.location.href = currentSong.url;
  });
  $(".share").click(function(event) {
    window.prompt("Copy direct link to song: Ctrl+C, Enter", "jfeliz.com/songs/" + currentSong.id);
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
  $("#forward").show();
  $("#backward").show();
  $("p#" + song.id + ".song-details").show();
  $(".song-details").hide();
  $("div#" + song.id + ".song-details").show();
  $(".song-link").removeClass("active");
  $(".song-link#" + song.id).addClass("active");
  $("audio").attr("src", song.url);
  $("#song-name").text(song.name);
  $("#download").show();
}

function favorite(event) {
  var id = parseInt(event.currentTarget.id);
  $.ajax({
    type: "POST",
    url: "songs/" + event.currentTarget.id + "/favorite",
    contentType: "application/json",
    data: JSON.stringify({"id": id, "favorite": true}),
    success: function() {
      $("#" + event.currentTarget.id + ".fa.fa-heart-o.favorite").attr('class', 'fa fa-heart unfavorite');
    }
  }); 
}

function unfavorite(event) {
  var id = parseInt(event.currentTarget.id);
  $.ajax({
    type: "POST",
    url: "songs/" + event.currentTarget.id + "/favorite",
    contentType: "application/json",
    data: JSON.stringify({"id": id, "favorite": false}),
    success: function(){
      $("#" + event.currentTarget.id + ".fa.fa-heart.unfavorite").attr('class', 'fa fa-heart-o favorite');
    }
  });
}
