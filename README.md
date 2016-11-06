# jfelizandco

RESTful API for accessing music archive on s3

## Create

**Artist**

`POST /artists` 

(or for UI assistance `/create_artist`)

**Song**

`POST /artists/:id/songs`

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

## Delete

**Artist**

`DELETE /artists/:id/delete`

**Song**

`DELETE /artists/:id/songs/:song_id/delete`
`DELETE /songs/:id/delete`
`GET /artists/:id/songs/:song_id/delete`
`GET /songs/:id/delete`
