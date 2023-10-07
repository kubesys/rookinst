#!/bin/bash

#example
#chmod +x ceph_storage.sh
#./ceph_storage.sh file myfs 3 

# Check root
if [ $EUID -ne 0 ];then
echo "You must be root (or sudo) to run this script"
exit 1
fi

# Check kubectl
command -v kubectl >/dev/null 2>&1 || {
  echo >&2 "kubectl is required but not installed. Aborting."
  exit 1
}

# Check if Rook Ceph
if ! kubectl get cephcluster -n rook-ceph; then
  echo "Rook Ceph cluster is not deployed. Please deploy Rook Ceph first."
  exit 1
fi

# Check for required arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <system-type> <system-name> <replicated>"
  exit 1
fi

storage_type=$1
system_name=$2
replicated=$3
storage_class_name="${system_name}-sc"

timeout=300 # filesystem deploy 5 minutes timeout

yaml_filename="$system_name.yaml"

# Check for valid storage system type input
if [ "$storage_type" != "file" ] && [ "$storage_type" != "block" ]; then
  echo "Invalid storage system type. Aborting."
  exit 1
fi

# Check if filesystem already exists
if [ "$storage_type" == "file" ] && kubectl get cephfilesystem "$system_name" -n rook-ceph &>/dev/null; then
  echo "Ceph filesystem '$system_name' already exists in namespace 'rook-ceph'."
  exit 1
fi

# Check if blockpool already exists
if [ "$storage_type" == "block" ] && kubectl get cephblockpool "$system_name" -n rook-ceph &>/dev/null; then
  echo "Ceph blockpool '$system_name' already exists in namespace 'rook-ceph'."
  exit 1
fi

# Check if storageclass already exists
if kubectl get storageclass "$storage_class_name" &>/dev/null; then
  echo "StorageClass '$storage_class_name' already exists."
  exit 1
fi

#------------------------------------------------------------------#

#file
create_ceph_file_system() {
  cat <<EOF >"$yaml_filename"
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: $system_name
  namespace: rook-ceph
spec:
  metadataPool:
    replicated:
      size: $replicated
  dataPools:
    - name: replicated
      replicated:
        size: $replicated
  preserveFilesystemOnDelete: false
  metadataServer:
    activeCount: 1
    activeStandby: true

---

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $storage_class_name
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: $system_name
  pool: $system_name-replicated
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
reclaimPolicy: Delete
EOF

  echo "YAML file '$yaml_filename' created successfully."

}

#block
create_ceph_block_system() {
  # Create YAML file with definitions for Ceph Block Storage
  cat <<EOF >"$yaml_filename"
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: $system_name
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: $replicated
---

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $storage_class_name
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: $system_name
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  csi.storage.k8s.io/fstype: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF

  echo "YAML file '$yaml_filename' created successfully."

}

wait_system_ready() {
  # Deploy Ceph storage system and StorageClass using kubectl apply
  kubectl apply -f "$yaml_filename"

  # Wait for CephFilesystem to be ready with a timeout
  start_time=$(date +%s)
  while true; do
    if [ "$storage_type" == "file" ]; then
      phase=$(kubectl get cephfilesystem "$system_name" -n rook-ceph -o jsonpath='{.status.phase}' 2>/dev/null)
    elif [ "$storage_type" == "block" ]; then
      phase=$(kubectl get cephblockpool "$system_name" -n rook-ceph -o jsonpath='{.status.phase}' 2>/dev/null)
    fi

    if [ "$phase" = "Ready" ]; then
      break
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge $timeout ]; then
      echo "Timed out waiting for Ceph'$storage_type'system to be ready."
      exit 1
    fi

    echo "Waiting for Ceph'$storage_type'system '$system_name' to be ready..."
    sleep 5
  done

  echo "Ceph${storage_type}system '$system_name' is ready."
}

#------------------------------------------------------------------#


#create storage system
if [ "$storage_type" = "file" ]; then
  create_ceph_file_system
elif [ "$storage_type" = "block" ]; then
  create_ceph_block_system
else
  echo "Invalid storage system type. Aborting."
  exit 1
fi

wait_system_ready


