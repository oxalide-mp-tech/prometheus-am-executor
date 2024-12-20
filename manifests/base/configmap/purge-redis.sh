#!/bin/bash
set -euo pipefail

if [[ "$AMX_STATUS" = "resolved" ]]; then
	kubectl delete -f /manifests-v1/purge-key-without-ttl-job.yaml || exit 0
	exit 0
fi

main() {
	for i in $(seq 1 "$AMX_ALERT_LEN"); do
		kubectl apply -f /manifests-v1/purge-key-without-ttl-job.yaml
	done
	wait
}

main "$@"
