#!/usr/bin/env bash
# Create or reuse the public Object Storage bucket used by the Space Invaders site.
# Usage: OCI_COMPARTMENT_OCID=<compartment OCID> ./create-bucket.sh
#        ./create-bucket.sh  # prompts for the compartment OCID when it is not set

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bucket_name_file="$script_dir/.bucket-name"
compartment_id=${OCI_COMPARTMENT_OCID:-${OCI_COMPARTMENT_ID:-${OCI_CLI_COMPARTMENT_ID:-}}}

command -v oci >/dev/null 2>&1 || {
  echo "Required command not found: oci" >&2
  exit 1
}

namespace=$(oci os ns get --query 'data' --raw-output)

if [[ -s "$bucket_name_file" ]]; then
  bucket_name=$(<"$bucket_name_file")
  echo "Reusing bucket: $bucket_name"
else
  echo "This script will create a public Object Storage bucket."
  echo "The upload script will reuse the bucket it creates."
  echo

  if [[ -z "$compartment_id" ]]; then
    read -r -p "OCI compartment OCID: " compartment_id
    if [[ -z "$compartment_id" ]]; then
      echo "A compartment OCID is required." >&2
      exit 1
    fi
  fi

  if command -v shasum >/dev/null 2>&1; then
    bucket_hash=$(printf '%s' "$namespace:$compartment_id" | shasum -a 256 | awk '{print $1}' | cut -c1-24)
  elif command -v sha256sum >/dev/null 2>&1; then
    bucket_hash=$(printf '%s' "$namespace:$compartment_id" | sha256sum | awk '{print $1}' | cut -c1-24)
  else
    echo "Required command not found: shasum or sha256sum" >&2
    exit 1
  fi

  bucket_name="space-invaders-${bucket_hash}"
  if oci os bucket get \
    --namespace-name "$namespace" \
    --bucket-name "$bucket_name" >/dev/null 2>&1; then
    echo "Reusing bucket: $bucket_name"
  else
    echo "Creating bucket: $bucket_name"
    oci os bucket create \
      --namespace-name "$namespace" \
      --compartment-id "$compartment_id" \
      --name "$bucket_name" \
      --public-access-type ObjectReadWithoutList >/dev/null
  fi

  printf '%s\n' "$bucket_name" >"$bucket_name_file"
fi

echo "Bucket: $bucket_name"
echo "Namespace: $namespace"
