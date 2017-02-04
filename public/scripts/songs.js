var currentSong;

$(window).on("load", function() {
  var isEditing = false;
  var songs = $.parseJSON($("#json-data").html());
  var currentSongIndex = 0;
  var page = 1;
  
  function nextSong() {
    return songs[++currentSongIndex % songs.length];
  }
  function lastSong() {
    return songs[--currentSongIndex % songs.length];
  }
  $(window).scroll(function() {
     if ($(window).scrollTop() + window.innerHeight == $(document).height()) {
       page += 1;
       $.ajax({
         type: "GET",
         url: "songs?page=" + page,
         dataType: "json",
         success: function(data) {
           songs.concat(data);
           addSongsHtml(data);
         }
       }); 
     }
  });
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
    event.stopPropagation();
  });
  $(".unfavorite").click(function(event) {
    if(event.currentTarget.className == "fa fa-heart unfavorite") {
      unfavorite(event);
    } else {
      favorite(event);
    }
    event.stopPropagation();
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
    event.stopPropagation();
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
    data: JSON.stringify({"id": id, "favorite": true})
  }); 

  $("#" + event.currentTarget.id + ".fa.fa-heart-o.favorite").attr('class', 'fa fa-heart unfavorite');
}

function unfavorite(event) {
  var id = parseInt(event.currentTarget.id);
  $.ajax({
    type: "POST",
    url: "songs/" + event.currentTarget.id + "/favorite",
    contentType: "application/json",
    data: JSON.stringify({"id": id, "favorite": false})
  });
  $("#" + event.currentTarget.id + ".fa.fa-heart.unfavorite").attr('class', 'fa fa-heart-o favorite');
}

function addSongsHtml(songs) {
  for (var i = 0; i < songs.length; i++) {
    var song = songs[i];
    var artistStr = "";
    for (var j = 0; j < song.artists.length; j++) {
      var artist = song.artists[j];
      artistStr += artist.name + " ";
    }
    var likedHtml = "";
    if (song.liked) {
      likedHtml = "<i class='fa fa-heart unfavorite' aria-hidden='true' id=" + song.id + "/>"
    } else {
      likedHtml = "<i class='fa fa-heart-o favorite' aria-hidden='true' id=" + song.id + "/>"
    }
    var likesStr = "";
    if (song.likes > 0) {
      likesStr = "x" + song.likes;
    }
    $("#song-list").append(
      "<div class='list-group-item list-group-item-action song-link' id=" + song.id + ">"
      + "<h5 href='#' class='list-group-item-heading'>" + song.name + "</h5>"
      + "<p class='list-group-item-text'>  by: " + artistStr + "</p>"
      + "<p class='list-group-item-text'>" + likedHtml + likesStr + "</p>"
      + "<div class='song-details' style='display: none;' id=" + song.id + ">"
        + "<button type='button' class='btn btn-secondary download'>Download</button>"
        + "<button type='button' class='btn btn-secondary share'>Share</button>"
      + "</div>"
    + "</div>"
    );
  }
}
