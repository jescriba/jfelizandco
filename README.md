# jfelizandco

RESTful API for accessing music archive on s3

## Create

**Artist**

`POST /artists` 

(UI assistance `GET /create_artist`)

**Song**

`POST /artists/:id/songs`

(UI assistance `GET /create_songs`)

## Read

**Artist**

`GET /artists`

**Song**

`GET /artists/:id/songs`
`GET /artists/:id/songs/:song_id`
`GET /songs`
`GET /songs/:id`

## Update

**Artist**

TODO - `PUT /artists/:id`

**Song**

`PUT /songs/:id`

(UI assistance `GET /songs/:id/edit`)

## Delete

**Artist**

`DELETE /artists/:id/delete`

**Song**

`DELETE /artists/:id/songs/:song_id/delete`
`DELETE /songs/:id/delete`
`GET /artists/:id/songs/:song_id/delete`
`GET /songs/:id/delete`
