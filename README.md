# Borg Volume Sync

## Purpose

This image pulls down the latest Borg backup from a remote server into a local Kubernetes (temporary) volume, runs alongside the service as a sidecar, while periodically backing up the volume state to the remote Borg server.

The intention is to run services as eventually-consistent with acceptable data loss, without the overheads of network file shares.

**DO NOT** use this for production services, or services which depend on strong data consistency!

More suitable applications include:
 - Grafana instances (storing dashboards)
 - Openhab (plugin downloads, local config, time series)
 - etc.

