terraform {
  required_providers {
    spotify = {
      version = "~> 0.2.6"
      source  = "conradludgate/spotify"
    }
  }
}

provider "spotify" {
  api_key = var.spotify_api_key
}

data "spotify_search_track" "BOC_01" {
  artist = "BUMP OF CHICKEN"
  album = "FLAME VEIN +1"
}
data "spotify_search_track" "BOC_02" {
  artist = "BUMP OF CHICKEN"
  album = "THE LIVING DEAD"
}
data "spotify_search_track" "BOC_03" {
  artist = "BUMP OF CHICKEN"
  album = "jupiter"
}
data "spotify_search_track" "BOC_04" {
  artist = "BUMP OF CHICKEN"
  album = "ユグドラシル"
}
data "spotify_search_track" "BOC_05" {
  artist = "BUMP OF CHICKEN"
  album = "orbital period"
}

resource "spotify_playlist" "play01" {
  name        = "High School hits"
  description = "This playlist was created by Terraform"
  public      = true

  tracks = [
    data.spotify_search_track.BOC_01.tracks[0].id, # アルエ
    data.spotify_search_track.BOC_01.tracks[5].id, # バトルクライ
    data.spotify_search_track.BOC_02.tracks[0].id, # K
    data.spotify_search_track.BOC_03.tracks[0].id, # 天体観測
    data.spotify_search_track.BOC_03.tracks[1].id, # ハルジオン
    data.spotify_search_track.BOC_04.tracks[0].id, # 車輪の唄
    data.spotify_search_track.BOC_04.tracks[1].id, # sailing day
    data.spotify_search_track.BOC_04.tracks[2].id, # スノースマイル
    data.spotify_search_track.BOC_04.tracks[5].id, # 乗車権
    data.spotify_search_track.BOC_05.tracks[0].id, # カルマ
    data.spotify_search_track.BOC_05.tracks[1].id, # 花の名
    data.spotify_search_track.BOC_05.tracks[2].id, # プラネタリウム
    data.spotify_search_track.BOC_05.tracks[3].id, # メーデー
    data.spotify_search_track.BOC_05.tracks[4].id, # 才悩人応援歌
    data.spotify_search_track.BOC_05.tracks[5].id, # 涙のふるさと
    data.spotify_search_track.BOC_05.tracks[6].id, # supernova
    data.spotify_search_track.BOC_05.tracks[7].id, # ハンマーソングと痛みの塔
  ]
}
