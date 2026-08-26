#!/usr/bin/env bash
set -euo pipefail

base_url="https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1"
model_id="xai.grok-4.20-0309-reasoning"
model_name="Grok"
api_key="${TF_VAR_genai_api_key:-}"
answer=""

printf 'Model ID [%s]: ' "$model_id"
read -r answer
[ -n "$answer" ] && model_id="$answer"

if [[ "$model_id" == ocid1.* ]]; then
    oci_region="$(printf '%s' "$model_id" | cut -d. -f4)"
    if [[ -z "$oci_region" ]]; then
        echo '<install_opencode> unable to determine the OCI region from the endpoint OCID' >&2
        exit 1
    fi
    base_url="https://inference.generativeai.${oci_region}.oci.oraclecloud.com/20231130/actions/v1"
    model_name="DAC"
else
    printf 'OCI Generative AI base URL [%s]: ' "$base_url"
    read -r answer
    [ -n "$answer" ] && base_url="$answer"

    printf 'Model name [%s]: ' "$model_name"
    read -r answer
    [ -n "$answer" ] && model_name="$answer"
fi

printf 'OCI Generative AI API key%s: ' "${api_key:+ [press Enter to keep the existing value]}"
read -r answer
printf '\n'
[ -n "$answer" ] && api_key="$answer"

if [ -z "$api_key" ]; then
    echo '<install_opencode> OCI Generative AI API key is required' >&2
    exit 1
fi

install_opencode() {
    echo "<install_opencode>"
    curl -fsSL https://opencode.ai/install | bash

    mkdir -p "$HOME/.local/share/opencode"

    mkdir -p "$HOME/.config/opencode"
    cat > "$HOME/.config/opencode/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "oci-genai": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OCI Generative AI",
      "options": {
        "baseURL": "${base_url}",
        "apiKey": "{file:~/.config/opencode/oci-genai-api-key}"
      },
      "models": {
        "${model_id}": {
          "name": "${model_name}"
        }
      }
    }
  },
  "model": "oci-genai/${model_id}"
}
EOF
    echo "<install_opencode> ~/.config/opencode/opencode.json created" 
    printf '%s\n' "$api_key" > "$HOME/.config/opencode/oci-genai-api-key"
    chmod 600 "$HOME/.config/opencode/oci-genai-api-key"
    echo "<install_opencode> ~/.config/opencode/oci-genai-api-key created" 

    export PATH="$HOME/.opencode/bin:$PATH"
    if grep -q ".opencode" $HOME/.bashrc; then
        echo '$HOME/.bashrc already updated'
    else
        echo 'export PATH="$HOME/.opencode/bin:$PATH' >> $HOME/.bashrc
    fi
}

install_opencode
