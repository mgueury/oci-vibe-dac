#!/usr/bin/env bash
# Create or reuse a public Object Storage bucket and upload this directory's assets.
# Usage: OCI_COMPARTMENT_ID=<compartment OCID> ./deploy.sh
#        ./deploy.sh  # prompts for the compartment OCID when it is not set

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bucket_name_file="$script_dir/.bucket-name"

namespace=$(oci os ns get --query 'data' --raw-output)

url_encode() {
  local value=$1 encoded='' character
  local index
  local LC_ALL=C

  for ((index = 0; index < ${#value}; index++)); do
    character=${value:index:1}
    case "$character" in
      [a-zA-Z0-9.~_/-]) encoded+=$character ;;
      *) printf -v character '%%%02X' "'$character"; encoded+=$character ;;
    esac
  done

  printf '%s' "$encoded"
}

if [[ -s "$bucket_name_file" ]]; then
  bucket_name=$(<"$bucket_name_file")
else
  echo "This script will create an Object Storage Bucket and upload the html(s) page to it."
  echo "The next run will reuse the same bucket."
  echo "To do this, it needs your Compartment OCID"
  echo
  # Compartment ID is needed only if the bucket has to be created
  if [[ "$OCI_COMPARTMENT_OCID" == "" ]]; then
    read -r -p "OCI compartment OCID: " OCI_COMPARTMENT_OCID
    if [[ -z "$OCI_COMPARTMENT_OCID" ]]; then
      echo "A compartment OCID is required." >&2
      exit 1
    fi
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    bucket_hash=$(printf '%s' "$namespace:$compartment_id" | sha256sum | awk '{print $1}' | cut -c1-24)
  else
    echo "Required command not found: sha256sum" >&2
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

echo "Uploading files (excluding *.sh)"
html_objects=()
while IFS= read -r -d '' file; do
  object_name=${file#"$script_dir"/}
  echo "Uploading: $object_name"
  oci os object put \
    --namespace-name "$namespace" \
    --bucket-name "$bucket_name" \
    --name "$object_name" \
    --file "$file" \
    --force >/dev/null

  if [[ "$object_name" == *.html ]]; then
    html_objects+=("$object_name")
  fi
done < <(find "$script_dir" -type f ! -name '*.sh' ! -name '.bucket-name' -print0)

echo "Deployment complete."
echo "Bucket: $bucket_name"
echo "Namespace: $namespace"

if ((${#html_objects[@]})); then
  echo "Public HTML URL(s):"
  for object_name in "${html_objects[@]}"; do
    printf 'https://objectstorage.%s.oraclecloud.com/n/%s/b/%s/o/%s\n' \
      "$OCI_REGION" "$namespace" "$bucket_name" "$(url_encode "$object_name")"
  done
else
  echo "No HTML files were uploaded."
fi
