
kubectl run prometheus-am-executor --image=azman0101/prometheus-am-executor:latest --namespace prometheus-am-executor -o yaml --dry-run > ./manifests/deployment.yaml
echo "---" >> ./manifests/deployment.yaml
kubectl expose deployment --namespace prometheus-am-executor prometheus-am-executor --port=80 --target-port=http -o yaml --dry-run >> ./manifests/deployment.yaml
echo "---" >> ./manifests/deployment.yaml
kubectl create configmap --namespace prometheus-am-executor purge-key-without-ttl-job --from-file=redis-command.sh=./scripts/redis-command.sh -o yaml --dry-run >> ./manifests/deployment.yaml
kubectl create job --namespace prometheus-am-executor purge-key-without-ttl-job --image=redis:5.0.3-alpine3.9 -o yaml --dry-run -- date > purge-key-without-ttl-job.yaml

echo "---" >> ./manifests/deployment.yaml
kubectl create role --namespace prometheus-am-executor allow-create-job-redis-purge --verb=create --verb=list --verb=get --resource=job --dry-run -o yaml >> ./manifests/deployment.yaml

echo "---" >> ./manifests/deployment.yaml
kubectl create rolebinding --namespace prometheus-am-executor allow-default-to-purge-redis-keys --role=allow-create-job-redis-purge  --serviceaccount=prometheus-am-executor:default --dry-run -o yaml >> ./manifests/deployment.yaml

```
{'receiver': 'relkon', 'status': 'firing', 'alerts': [{'status': 'firing', 'labels': {'alertname': 'RedisNoExpiringKeys', 'prometheus'` 'monitoring/kube-prometheus-prometheus-prometheus', 'service': 'redis', 'severity': 'warning'}, 'annotations': {'description': 'The Redis cluster at `` had not expiring keys', 'summary': 'Redis cluster ` had more than 0 expiring key'}, 'startsAt': '2020-06-16T10:22:14.559Z', 'endsAt': '0001-01-01T00:00:00Z', 'generatorURL': 'http://prometheus.mon.prod.gcp.example.fr/graph?g0.expr=sum%28redis_db_keys%7Bjob%3D%22kv-memory-exporter%22%7D%29+-+sum%28redis_db_keys_expiring%7Bjob%3D%22kv-memory-exporter%22%7D%29+%3E+0&g0.tab=1', 'fingerprint': '337e43b2d90b8542'}], 'groupLabels': {}, 'commonLabels': {'alertname': 'RedisNoExpiringKeys', 'prometheus': 'monitoring/kube-prometheus-prometheus-prometheus', 'service': 'redis', 'severity': 'warning'}, 'commonAnnotations': {'description': 'The Redis cluster at `` had not expiring keys', 'summary': 'Redis cluster ` had more than 0 expiring key'}, 'externalURL': 'http://alertmanager.mon.prod.gcp.example.fr', 'version': '4', 'groupKey': '{}:{}'}
```
