#!/bin/bash

# delete top of the Rook cluster
# delete the ceph object store
kubectl -n rook-ceph delete cephobjectstore my-store

for CRD in $(kubectl get crd -n rook-ceph | awk '/ceph.rook.io/ {print $1}'); do
kubectl get -n rook-ceph "$CRD" -o name | 
xargs -I {} kubectl patch -n rook-ceph {} --type merge -p '{"metadata":{"finalizers": []}}'
done
# delete the CephCluster CRD
# kubectl -n rook-ceph patch cephcluster rook-ceph --type merge -p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data"}}}'
# kubectl -n rook-ceph delete cephcluster rook-ceph
kubectl delete -f cluster/cluster.yaml
rm -rf /var/lib/rook

# Wait for CephCluster to be deleted
while kubectl -n rook-ceph get cephcluster rook-ceph &> /dev/null; do
    echo "Waiting for CephCluster to be deleted..."
    sleep 5
done

# delete the Operator and related Resources
kubectl delete -f cluster/operator.yaml
kubectl delete -f cluster/common.yaml
kubectl patch -n rook-ceph cm/rook-ceph-mon-endpoints --type merge -p '{"metadata":{"finalizers": []}}'
kubectl patch -n rook-ceph secret/rook-ceph-mon --type merge -p '{"metadata":{"finalizers": []}}'
kubectl delete -f cluster/crds.yaml
# kubectl delete -f cluster/dashboard-exporter.yaml

# kubectl delete -f object/object-bucket-claim-delete.yaml
# kubectl delete -f object/storageclass-bucket-delete.yaml 
# kubectl delete -f object/object.yaml