# Spotify


```bash
export SPOTIFY_CLIENT_REDIRECT_URI=http://localhost:27228/spotify_callback

# Do not commit the ".env" file to git because it is confidential.
docker run --rm -it -p 27228:27228 --env-file ./.env ghcr.io/conradludgate/spotify-auth-proxy
```


## References

- [Create a Spotify Playlist with Terraform](https://learn.hashicorp.com/tutorials/terraform/spotify-playlist)
