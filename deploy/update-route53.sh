#!/usr/bin/env bash
# Update the Route 53 A records for this box's public domains to its CURRENT
# public IPv4. Run on every boot so we can avoid paying for an Elastic IP: a
# stopped instance gets a new public IP on start, and this points DNS at it.
#
# One box hosts four apps, so we upsert four records in a single batch:
#   lcg.leohyl.app  ringsdb.leohyl.app  marvelcdb.leohyl.app  ashes.leohyl.app
#
# Requires: AWS CLI v2 + an instance IAM role allowing
#   route53:ChangeResourceRecordSets and route53:ListHostedZonesByName
# on the leohyl.app hosted zone.
set -euo pipefail

ZONE_NAME="leohyl.app."     # trailing dot required by Route 53
TTL=60
DOMAINS=(lcg.leohyl.app ringsdb.leohyl.app marvelcdb.leohyl.app ashes.leohyl.app)

# --- Get this instance's public IPv4 via IMDSv2 (token-based metadata) --------
TOKEN="$(curl -fsS -X PUT 'http://169.254.169.254/latest/api/token' \
	-H 'X-aws-ec2-metadata-token-ttl-seconds: 300')"
PUBLIC_IP="$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" \
	'http://169.254.169.254/latest/meta-data/public-ipv4')"

if [[ -z "${PUBLIC_IP:-}" ]]; then
	echo "ERROR: could not determine public IPv4 from instance metadata" >&2
	exit 1
fi
echo "Instance public IP: $PUBLIC_IP"

# --- Find the hosted zone id --------------------------------------------------
ZONE_ID="$(aws route53 list-hosted-zones-by-name \
	--dns-name "$ZONE_NAME" \
	--query "HostedZones[?Name=='${ZONE_NAME}'].Id | [0]" \
	--output text | sed 's#/hostedzone/##')"

if [[ -z "$ZONE_ID" || "$ZONE_ID" == "None" ]]; then
	echo "ERROR: hosted zone $ZONE_NAME not found" >&2
	exit 1
fi
echo "Hosted zone: $ZONE_ID"

# --- Build a batch with one UPSERT per domain ---------------------------------
CHANGES=""
for DOMAIN in "${DOMAINS[@]}"; do
	[[ -n "$CHANGES" ]] && CHANGES+=","
	CHANGES+="{
		\"Action\": \"UPSERT\",
		\"ResourceRecordSet\": {
			\"Name\": \"${DOMAIN}.\",
			\"Type\": \"A\",
			\"TTL\": ${TTL},
			\"ResourceRecords\": [{\"Value\": \"${PUBLIC_IP}\"}]
		}
	}"
done

aws route53 change-resource-record-sets \
	--hosted-zone-id "$ZONE_ID" \
	--change-batch "{\"Comment\": \"lcg boot-time IP update\", \"Changes\": [${CHANGES}]}" >/dev/null

echo "Updated ${DOMAINS[*]} -> ${PUBLIC_IP} (TTL ${TTL})"
