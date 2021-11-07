output "playlist_url" {
  value       = "https://open.spotify.com/playlist/${spotify_playlist.play01.id}"
  description = "Visit this URL in your browser to listen to the playlist"
}
