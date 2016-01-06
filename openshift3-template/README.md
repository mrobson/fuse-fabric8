OpenShift 3.1 Templates
=======================
There are 2 types of included templates, ones without a PersistentVolume for a mavan localRepository and ones with a PersistentVolume for a mavan localRepository.

To use the PV templates, you must have an NFS server which is accessible from within your PODs and configure it in the template. The variable PV_NFS_PATH is used both for the export directory and local directory name.
```
{
    "name": "PV_NFS_PATH",
    "description": "NFS Mount Path for the PersistentVolume",
    "value": "/mnt/maven"
}
{
    "name": "PV_NFS_SERVER",
    "description": "NFS Server for the PersistentVolume",
    "value": "nfsserver.example.com"
}
```
fuse-fabric8-template-1ens-1srv.json
------------------------------------
* 1 Ensemble Server
* 1 Fabric Server

fuse-fabric8-template-1ens-1srv-pv.json
---------------------------------------
* 1 Ensemble Server
* 1 Fabric Server
* PersistentVolume for mavan localRepository

fuse-fabric8-template-1ens-2srv.json
------------------------------------
* 1 Ensemble Server
* 2 Fabric Server

fuse-fabric8-template-1ens-2srv-pv.json
---------------------------------------
* 1 Ensemble Server
* 2 Fabric Server
* PersistentVolume for mavan localRepository

fuse-fabric8-template-3ens-2srv.json
------------------------------------
* 3 Ensemble Server
* 2 Fabric Server
* PersistentVolume for mavan localRepository

fuse-fabric8-template-3ens-2srv-pv.json
---------------------------------------
* 3 Ensemble Server
* 2 Fabric Server
* PersistentVolume for mavan localRepository

fuse-fabric8-template-5ens-3srv.json
------------------------------------
* 5 Ensemble Server
* 3 Fabric Server
* PersistentVolume for mavan localRepository

fuse-fabric8-template-5ens-3srv-pv.json
---------------------------------------
* 5 Ensemble Server
* 3 Fabric Server
* PersistentVolume for mavan localRepository
