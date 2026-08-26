#!/usr/bin/env bash
# Create or reuse a public Object Storage bucket and upload this directory's assets.
# Usage: OCI_COMPARTMENT_ID=<compartment OCID> ./deploy.sh
#        ./deploy.sh  # prompts for the compartment OCID when it is not set

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bucket_name_file="$script_dir/.bucket-name"
compartment_id=${OCI_COMPARTMENT_ID:-${OCI_CLI_COMPARTMENT_ID:-}}

if [[ -z "$compartment_id" ]]; then
  read -r -p "OCI compartment OCID: " compartment_id
  if [[ -z "$compartment_id" ]]; then
    echo "A compartment OCID is required." >&2
    exit 1
  fi
fi

for command in oci; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

namespace=$(oci os ns get --query 'data' --raw-output)

if [[ -s "$bucket_name_file" ]]; then
  bucket_name=$(<"$bucket_name_file")
else
  if command -v shasum >/dev/null 2>&1; then
    bucket_hash=$(printf '%s' "$namespace:$compartment_id" | shasum -a 256 | awk '{print $1}' | cut -c1-24)
  elif command -v sha256sum >/dev/null 2>&1; then
    bucket_hash=$(printf '%s' "$namespace:$compartment_id" | sha256sum | awk '{print $1}' | cut -c1-24)
  else
    echo "Required command not found: shasum or sha256sum" >&2
    exit 1
  fi
  bucket_name="space-invaders-${bucket_hash}"
fi

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

echo "Uploading files (excluding *.sh)"
while IFS= read -r -d '' file; do
  object_name=${file#"$script_dir"/}
  echo "Uploading: $object_name"
  oci os object put \
    --namespace-name "$namespace" \
    --bucket-name "$bucket_name" \
    --name "$object_name" \
    --file "$file" \
    --force >/dev/null
done < <(find "$script_dir" -type f ! -name '*.sh' ! -name '.bucket-name' -print0)

echo "Deployment complete."
echo "Bucket: $bucket_name"
echo "Namespace: $namespace"
