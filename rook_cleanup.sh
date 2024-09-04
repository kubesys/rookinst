#!/bin/bash

# delete top of the Rook cluster


# delete the CephCluster CRD
kubectl -n rook-ceph patch cephcluster rook-ceph --type merge -p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data"}}}'
kubectl -n rook-ceph delete cephcluster rook-ceph
rm -rf /var/lib/rook

# Wait for CephCluster to be deleted
while kubectl -n rook-ceph get cephcluster rook-ceph &> /dev/null; do
    echo "Waiting for CephCluster to be deleted..."
    sleep 5
done

# delete the Operator and related Resources
kubectl delete -f cluster/operator.yaml
kubectl delete -f cluster/common.yaml
kubectl delete -f cluster/crds.yaml
# kubectl delete -f cluster/dashboard-exporter.yaml

# kubectl delete -f object/object-bucket-claim-delete.yaml
# kubectl delete -f object/storageclass-bucket-delete.yaml 
# kubectl delete -f object/object.yaml
