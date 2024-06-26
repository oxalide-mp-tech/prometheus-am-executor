[![CircleCI](https://circleci.com/gh/imgix/prometheus-am-executor.svg?style=svg)](https://circleci.com/gh/imgix/prometheus-am-executor)

# prometheus-am-executor

The prometheus-am-executor is a HTTP server that receives alerts from the
[Prometheus Alertmanager](https://prometheus.io/docs/alerting/alertmanager/) and
executes a given command with alert details set as environment variables.

:information_source: **This project's development is currently stale**

We haven't needed to update this program in some time. If you are looking for
something with similar functionality and is more actively maintained,
[@aantn](https://github.com/aantn) has suggested their project:
[Robusta](https://github.com/robusta-dev/robusta) ([docs](https://docs.robusta.dev/master/))

[issue 7](https://github.com/imgix/prometheus-am-executor/issues/7)
has discussion relating to the status of this project.

## Building

##### Requirements

* [Git](https://git-scm.com/downloads)
* [Go](https://golang.org/doc/install)


#### 1. Clone this repository

```
git clone https://github.com/imgix/prometheus-am-executor.git
```

#### 2. Compile the `prometheus-am-executor` binary

```
go test -count 1 -v ./...

go build
```

## Usage

```
Usage: ./prometheus-am-executor [options] script [args..]

  -f string
        YAML config file to use
  -l string
    	HTTP Port to listen on (default ":8080")
  -v	Enable verbose/debug logging
```

The executor runs the provided script(s) (set via cli or yaml config file) with the following environment variables
set:

- `AMX_RECEIVER`: name of receiver in the AM triggering the alert
- `AMX_STATUS`: alert status
- `AMX_EXTERNAL_URL`: URL to reach alertmanager
- `AMX_ALERT_LEN`: Number of alerts; for iterating through `AMX_ALERT_<n>..` vars
- `AMX_LABEL_<label>`: alert label pairs
- `AMX_GLABEL_<label>`: label pairs used to group alert
- `AMX_ANNOTATION_<key>`: alert annotation key/value pairs
- `AMX_ALERT_<n>_STATUS`: status of alert
- `AMX_ALERT_<n>_START`: start of alert in seconds since epoch
- `AMX_ALERT_<n>_END`: end of alert, 0 for firing alerts
- `AMX_ALERT_<n>_URL`: URL to metric in prometheus
- `AMX_ALERT_<n>_FINGERPRINT`: Message Fingerprint
- `AMX_ALERT_<n>_LABEL_<label>`: <value> alert label pairs
- `AMX_ALERT_<n>_ANNOTATION_<key>`: <value> alert annotation key/value pairs


### Using a configuration file

If the `-f` flag is set, the program will read the given YAML file as configuration on startup. Any settings specified at the cli take precedence over the same settings defined in a config file.

This feature is useful if you wish to configure prometheus-am-executor to dispatch to multiple processes based on what labels match between an alert and a command configuration.

An [example config file](examples/executor.yml) is provided in the examples directory.

#### Configuration file format

```yaml
---
listen_address: ":23222"
verbose: false
# tls_key: "certs/key.pem"
# tls_crt: "certs/cert.pem"
commands:
  - cmd: echo
    args: ["banana", "tomato"]
    match_labels:
      "env": "testing"
      "owner": "me"
    notify_on_failure: false
  - cmd: /bin/true
    max: 3
    ignore_resolved: true
  - cmd: /bin/sleep
    args: ["10s"]
    resolved_signal: SIGUSR1
```

|Parameter|Use|
|---------|---|
|`listen_address`|HTTP Port to listen on. Equivalent to the `-l` cli flag.|
|`verbose`|Enable verbose/debug logging. Equivalent to the `-v` cli flag.|
|`tls_key`|The TLS Key file for an optional TLS listener.|
|`tls_crt`|The TLS Certificate file for an optional TLS listener.|
|`commands`|A config section that specifies one or more commands to execute when alerts are received.|
|`cmd`|The name or path to the command you want to execute.|
|`args`|Optional arguments that you want to pass to the command|
|`match_labels`|What alert labels you'd like to use, to determine if the command should be executed. **All** specified labels must match in order for the command to be executed. If `match_labels` isn't specified, the command will be executed for _all_ alerts.|
|`notify_on_failure`|By default if any executed command returns a non-zero exit code, the caller (alertmanager) is notified with an HTTP 500 status code in the response. This will likely result in alertmanager considering the message a 'failure to notify' and re-sends the alert to am-executor. If this is not desired behaviour, set `nofity_on_failure` to `false`.|
|`max`|The maximum instances of this command that can be running at the same time. A zero or negative value is interpreted as 'no limit'.|
|`ignore_resolved`|By default when an alertmanager message indicating the alerts are 'resolved' is received, any commands matching the alarm are sent a signal if they are still active. If this is not desired behaviour, set this to `true`.|
|`resolved_signal`|Specify which signal to send to matching commands that are still running when the triggering alert is resolved. (default: SIGKILL)|

In the above configuration example:
* `echo` will be executed when an alert has the labels `env="testing"` and `owner="me"`, receives SIGKILL if triggering alarm resolves while it's still running. If the command fails, the source of the alert isn't notified.
* `/bin/true` will be executed for all alerts, and doesn't receive a signal if triggering alarm resolves while running.
* `/bin/sleep` is executed for all alerts, and receives SIGUSR1 signal if triggering alarm resolves while still running.

##### Creating TLS Certificates

With the following command can you create a TLS key and certificate for testing purposes.

```
mkdir certs
cd certs
go run $(go env GOROOT)/src/crypto/tls/generate_cert.go --rsa-bits=2048 --host=localhost
```

#### Testing configuration file changes

If you'd like to check the behaviour of a configuration file when prometheus-am-executor receives alerts, you can use the [curl](https://curl.haxx.se/) command to replay an alert. An example alert payload is [provided in the examples directory](examples/alert_payload.json).

##### 1. Start prometheus-am-executor with your configuration file

```
./prometheus-am-executor -f examples/executor.yml -v
```

##### 2. Send an alert to prometheus-am-executor

Make sure the port used in the curl command matches whatever you specified.

```
curl --include -H 'Content-Type: application/json' --data-binary "@examples/alert_payload.json" -X GET 'http://localhost:23222/'
```

##### 3. Check the output of prometheus-am-executor

## Example: Reboot systems with errors

Sometimes a system might exhibit errors that require a hard reboot. This is an
example on how to use Prometheus and prometheus-am-executor to reboot a machine
a machine based on a alert while making sure enough instances are in service
all the time.

Let assume the counter `app_errors_unrecoverable_total` should trigger a reboot
if increased by 1. To make sure enough instances are in service all the time,
the reboot should only get triggered if at least 80% of all instances are
reachable in the load balancer. A alerting expression would look like this:

```
ALERT RebootMachine IF
	increase(app_errors_unrecoverable_total[15m]) > 0 AND
	avg by(backend) (haproxy_server_up{backend="app"}) > 0.8
```

This will trigger an alert `RebootMachine` if `app_errors_unrecoverable_total`
increased in the last 15 minutes and there are at least 80% of all servers for
backend `app` up.

Now the alert needs to get routed to prometheus-am-executor like in this 
[alertmanager config](examples/alertmanager.yml) example.

Finally prometheus-am-executor needs to be pointed to a reboot script:

```
./prometheus-am-executor examples/reboot
```

As soon as the counter increases by 1, an alert gets triggered and the
alertmanager routes the alert to prometheus-am-executor which executes the
reboot script.

### Caveats

To make sure a system doesn't get rebooted multiple times, the 
`repeat_interval` needs to be longer than interval used for `increase()`. As
long as that's the case, prometheus-am-executor will run the provided script
only once.

`increase(app_errors_unrecoverable_total[15m])` takes the value of
`app_errors_unrecoverable_total` 15 minutes ago to calculate the increase, it's
required that the metric already exists *before* the counter increase happens.
The Prometheus client library sets counters to 0 by default, but only for
metrics without dynamic labels. Otherwise the metric only appears the first time
it is set. The alert won't get triggered if the metric uses dynamic labels and
was incremented the very first time (the increase from 'unknown to 0). Therefor
you **need** to initialize all error counters with 0.

Since the alert gets triggered if the counter increased in the last 15 minutes,
the alert resolves after 15 minutes without counter increase, so it's important
that the alert gets processed in those 15 minutes or the system won't get
rebooted.
