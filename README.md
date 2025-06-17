# Borg Volume Sync

## Purpose

This image pulls down the latest Borg backup from a remote server into a local Kubernetes (temporary) volume, runs alongside the service as a sidecar, while periodically backing up the volume state to the remote Borg server.

The intention is to run services as eventually-consistent with acceptable data loss, without the overheads of network file shares.

**DO NOT** use this for production services, or services which depend on strong data consistency!

More suitable applications include:
 - Grafana instances (storing dashboards)
 - Openhab (plugin downloads, local config, time series)
 - etc.

## Requirements

 - A Linux server which has Borg installed (check the system package manager)
 - A Kubernetes cluster

## Installation

Create an SSH keypair:

  ssh-keygen -f my_key

Install the SSH public key on the Borg backup server:

  ssh-copy-id -i ./my_key.pub user@backup-server

Initialize the Borg Repository (must be done once-per-service) - remember to write down the repokey:

  ssh -i my_key user@backup-server
  mkdir -p backups/my_service
  borg init -e repokey-blake2 backups/my_service

Create the secret in Kubernetes:

  kubectl create secret generic my-ssh-secret --from-file=ssh-privatekey=./my_key --from-file=ssh-publickey=./my_key.pub

You should be able to add the sidecar to an existing deployment/pod:

      initContainers:
        - name: borg
          image: aimmac23/borg-volume-sync:latest
          # This makes it be a side-car, rather than a normal init container
          restartPolicy: Always
          env:
            - name: ARCHIVE_NAME
              value: my_service
            - name: REPO_BASE
              value: user@backup-server:/home/user/backups
            - name: USER_UID
              value: "1005"
            - name: BORG_PASSPHRASE
              value: REPOKEY_FROM_BORG_INIT__REPLACE_ME
          startupProbe:
            exec:
               command:
                - cat
                - /tmp/READY
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 60
          volumeMounts:
            - name: storage
              mountPath: /data
            - name: ssh
              mountPath: /ssh-key

You'll need to add definitions to the volumes section (adapt "storage" name to match the service):

      volumes:
      - name: storage
        emptyDir:
          sizeLimit: 1G
      - name: ssh
        secret:
          secretName: my-ssh-secret
          defaultMode: 0400

Applying the new Kubeconfig should work - double-check the pod description:

  kubectl get pods
  kubectl describe pod/my_service_name

And check the sidecar container logs:

  kubectl logs pod/my_service_name -c borg

After a while you should be able to see the sidecar creating new backups:

    ssh -i my_key user@backup-server
    BORG_PASSPHRASE=REPLACEME borg list backups/my_service
