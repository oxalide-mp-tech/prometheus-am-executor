#!/bin/bash
set -euox pipefail
DEBIAN_FRONTEND=noninteractive apt update && apt install -yqq curl
DBS=$(/usr/local/bin/redis-cli -h kv-memory-redis-ha-announce-0.redis info keyspace | awk -F":" '{print $1}' | tail -n +2 | awk '{print substr($1,3); }')
for db_num in ${DBS}; do
    /usr/local/bin/redis-cli -h kv-memory-redis-ha-announce-0.redis -n ${db_num} --scan | while read LINE ; do TTL=$(redis-cli -n ${db_num} -h kv-memory-redis-ha-announce-0.redis -n ${db_num} ttl "$LINE"); if [ $TTL -eq  -1 ]; then echo "$LINE"; fi; done > "keys${db_num}.txt"
    echo "For DB ${db_num}:"
    /bin/cat "keys${db_num}.txt"
done
for n in {0..2}; do
    if /usr/local/bin/redis-cli -h kv-memory-redis-ha-announce-${n}.redis info | grep -E "role:master";
    then
        MASTER_REDIS_NUM=${n}
        echo "Redis Master is kv-memory-redis-ha-announce-${MASTER_REDIS_NUM}.redis"
        break
    fi
done
for db_num in ${DBS}; do
    for key in $(/bin/cat "keys${db_num}.txt"); do /usr/local/bin/redis-cli -h kv-memory-redis-ha-announce-${MASTER_REDIS_NUM}.redis -n ${db_num} del "${key}"; done
done

CHANNEL="${CHANNEL_CI-@julien.boulanger}"
USERNAME="PurgeRedisKeyWithoutTTL"
EMOJI=":information_source:"
KEYS=$(/bin/cat keys${db_num}.txt)
SLACK_MSG="Clé redis sans TTL purgée:\n${KEYS}"
PAYLOAD="payload={\"channel\": \"${CHANNEL}\", \"username\": \"${USERNAME}\", \"text\": \"${SLACK_MSG}\", \"icon_emoji\": \"${EMOJI}\"}"
# TODO: call slack to customer
if [ "${ENABLE_SLACK_NOTIFICATION:-true}" = "true" ]
then
    echo "Sending slack notification..."
    curl -sX POST --data-urlencode "${PAYLOAD}" "${SLACK_HOOK}"
else
    echo "Slack notification disabled"
fi
# TODO: delete job
