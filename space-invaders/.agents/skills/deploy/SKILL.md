---
name: deploy
description: Deploy the files in the current project directory to its existing OCI Object Storage bucket. Use when asked to upload, publish, or deploy the project from the current working directory after the bucket has been created.
---

# Deploy the Current Project

1. Treat the current working directory as the project to upload; do not change directories before running:

   ```bash
   project_directory=$(pwd -P)
   repository_root=$(git rev-parse --show-toplevel)
   ```

2. Verify that `$repository_root/.bucket-name` exists and is nonempty. If it is missing, stop and tell the user to run `bucket_create.sh` first; do not create a bucket.
3. Upload the recorded project directory with the repository uploader:

   ```bash
   "$repository_root/bucket_upload.sh" "$project_directory"
   ```

4. Report the public HTML URL or URLs printed by the uploader.
