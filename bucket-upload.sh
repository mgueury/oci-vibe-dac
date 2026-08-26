#!/usr/bin/env bash
# Upload Space Invaders assets to the bucket created by create-bucket.sh.
# Usage: ./upload-files.sh

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bucket_name_file="$script_dir/.bucket-name"
region=$OCI_REGION

if [[ ! -s "$bucket_name_file" ]]; then
  echo "Bucket state is missing. Run ./create-bucket.sh first." >&2
  exit 1
fi

if [[ -z "$1" ]]; then
  echo "Usage: ./bucket-upload.sh <directory>" >&2
  echo "ex: ./bucket-upload.sh space-invaders" >&2
  exit 1
fi

bucket_name=$(<"$bucket_name_file")
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

echo "Uploading files"
oci os object bulk-upload -ns $namespace -bn $bucket_name --src-dir $directory --overwrite --content-type auto  
echo "Upload complete."
echo "Bucket: $bucket_name"
echo "Namespace: $namespace"

echo "Public HTML URL(s):"
for object_name in "$(find "$directory" -type f -name '*.html' -print0)"; do
  printf 'https://objectstorage.%s.oraclecloud.com/n/%s/b/%s/o/%s\n' \
    "$region" "$namespace" "$bucket_name" "$(url_encode "$object_name")"
done
