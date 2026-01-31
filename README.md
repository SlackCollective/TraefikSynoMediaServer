# TraefikSynoMediaServer
Syno218+ docker mediaserver, Traefik as reverse proxy

This compose is currently using one common user for each Docker daemon, and a shared group. Admin group and the Docker group have R/W permissions in Control Panel/Shared folder for docker and data folders. To ensure correct permissions, the following commands from Trash's guide https://trash-guides.info/Hardlinks/How-to-setup-for/Synology/ were run (to change the folder and file permissions to be accessible to the "docker" group, as well as the individual user for services):
```
sudo chown -R docker:docker /volume1/data /volume1/docker/apps
sudo chmod -R a=,a+rX,u+w,g+w /volume1/data /volume1/docker/apps
```
Router ports forwarded to NAS:
Plex (32400 is default); Https: 443 (external) > 449 (internal). Also 80 (external) > 89 (internal) if you want to be able to redirect all web traffic to https.

# Containers in use:
### WEBSERVER/REVERSE PROXY/DNS/VPN
* traefik
### VPN
* Gluetun (supports multiple VPN providers)
### AUTH
* Google oauth
### HOMEPAGE
* organizr
### INDEXERS
* prowlarr
### DOWNLOADERS
* sabnzbd
* qbittorrent (using network_mode: service:gluetun)
### TORRENT MANAGEMENT
* qbit-manage
* autobrr
### MEDIA SEARCH
* sonarr
* radarr
### MEDIA EDITING
* tdarr
### HOME THEATRE
* plex
* tautulli
* jellyseerr (allow users to request media)
* maintainerr (automated Plex library maintenance)
### BOOKS & PDF
* calibre-web
### PASSWORD MANAGEMENT
* vaultwarden (self-hosted Bitwarden)
### SYSTEM MONITORING
* notifiarr
* dockhand

Requires docker-compose.yaml and .env file in the same directory, container folders beneath.
