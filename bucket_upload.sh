#!/usr/bin/env bash
# Upload a directory to the bucket created by bucket_create.sh.
# Usage: ./bucket_upload.sh <directory>

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bucket_name_file="$script_dir/.bucket-name"
directory=${1:-}

if [[ -z "$directory" ]]; then
  echo "Usage: ./bucket_upload.sh <directory>" >&2
  echo "ex: ./bucket_upload.sh space-invaders" >&2
  exit 1
fi
if [[ ! -d "$directory" ]]; then
  echo "Directory not found: $directory" >&2
  exit 1
fi

directory=$(cd -- "$directory" && pwd)
region=$OCI_REGION

command -v oci >/dev/null 2>&1 || {
  echo "Required command not found: oci" >&2
  exit 1
}

if [[ ! -s "$bucket_name_file" ]]; then
  echo "Bucket state is missing. The user should create the bucket first." >&2
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
oci os object bulk-upload \
  --namespace-name "$namespace" \
  --bucket-name "$bucket_name" \
  --src-dir "$directory" \
  --overwrite \
  --exclude "*.md" \
  --content-type auto
echo "Upload complete."
echo "Bucket: $bucket_name"
echo "Namespace: $namespace"

html_objects=()
while IFS= read -r -d '' file; do
  html_objects+=("${file#"$directory"/}")
done < <(find "$directory" -type f -name '*.html' -print0)

if ((${#html_objects[@]})); then
  echo "Public HTML URL(s):"
  for object_name in "${html_objects[@]}"; do
    printf 'https://objectstorage.%s.oraclecloud.com/n/%s/b/%s/o/%s\n' \
      "$region" "$namespace" "$bucket_name" "$(url_encode "$object_name")"
  done
fi
