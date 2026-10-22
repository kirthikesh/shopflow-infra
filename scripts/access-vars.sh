#!/usr/bin/env bash
# Writes generated/access.tfvars.json for the dev layer: who can reach the AKS API,
# and who administers the cluster and Key Vault.
#
# The same script runs on your laptop (through make) and on the pipeline agent,
# and both end up with the same values, so a laptop apply and a pipeline apply
# never undo each other.
#
#   API allow-list  the caller's public IP, plus JUMPBOX_IP and ADMIN_IP when known
#   Admins          owner    = you            (OWNER_OBJECT_ID, else your az login)
#                   pipeline = the agent VM   (PIPELINE_OBJECT_ID, else the management layer output)
set -euo pipefail
cd "$(dirname "$0")/.."

out=generated/access.tfvars.json
ip_re='^[0-9]{1,3}(\.[0-9]{1,3}){3}$'
id_re='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# Read a management-layer output if that layer exists; empty otherwise.
mgmt_output() {
  [ -d management/.terraform ] || return 0
  terraform -chdir=management output -raw "$1" 2>/dev/null | grep -E "$2" || true
}

my_ip=${MY_IP:-$(curl -s --max-time 5 https://api.ipify.org | grep -E "$ip_re" || true)}
jump_ip=${JUMPBOX_IP:-$(mgmt_output jumpbox_public_ip "$ip_re")}
owner=${OWNER_OBJECT_ID:-$(az ad signed-in-user show --query id -o tsv 2>/dev/null | grep -E "$id_re" || true)}
pipeline=${PIPELINE_OBJECT_ID:-$(mgmt_output jumpbox_principal_id "$id_re")}

[ -n "$my_ip" ] || { echo "Could not find this machine's public IP." >&2; exit 1; }
[ -n "$owner" ] || { echo "Could not find your Entra ID object ID. Run az login, or set OWNER_OBJECT_ID." >&2; exit 1; }

# Unique, sorted list of /32s.
ips=$(printf '%s\n' "$my_ip" "$jump_ip" "${ADMIN_IP:-}" | grep -E "$ip_re" | sort -u |
  sed 's|.*|"&/32"|' | paste -sd, -)

admins="\"owner\": \"$owner\""
[ -n "$pipeline" ] && admins="$admins, \"pipeline\": \"$pipeline\""

mkdir -p generated
cat >"$out" <<EOF
{
  "aks_api_server_authorized_ip_ranges": [$ips],
  "admin_object_ids": { $admins }
}
EOF
echo "AKS API allowed from: $ips"
echo "Admins: owner${pipeline:+, pipeline}"
