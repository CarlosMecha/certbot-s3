# Certbot S3

[Certbot](https://certbot.eff.org/) configured to run in a Docker image to create and renew certificates. Uses S3 as a file store. 

*IMPORTANT:* This is a work in progress project. Use at your own risk. If used in production, make a backup of the S3 folder *before* each run. 

## Creating certificates
When creating a certificate, it can use `standalone` or `dns-route-53` plugins of certbot, that provides authentication for your domains. For 
`standalone`, it will listen for requests in the port 80 during the verification on your domains. Usually a couple of seconds of downtime are
required for this process.

When Let's Encrypt has verified your domain, certbot will create the certificate and uploads it to S3 to the bucket (and path) provided. At that time,
any web server could pull the certificate from S3 and use it.

## Renewing certificates
Let's Encrypt certificates expire in 3 months. Periodic renewals are required to keep your SSL encryption working. When running, the container
will pull all certificates stored in the configured bucket and path in S3, and try to renew them, and upload them again to S3.

By default, the container only check once for renewals, and finish the execution, but you can make the container repeat the operation setting
`RENEW_INTERVAL=x` as the number of _hours_ between checks. Although, you can schedule renewals with AWS Scheduled tasks to save resources.

## Using the certificates in your web server
An easy way to keep your local certificates updated, you could run `aws sync s3://bucket/path-to-certs/ /etc/my-certs/`, and this command will
override the local certificates when a file in S3 changes (or adding missing ones). Then, you can reload the configuration of your webserver 
(ex. `nginx reload`) to use them. Here's an example of how to configure your web server environment with cron:

```
0 * * * * aws sync s3://bucket/path-to-certs/ /etc/my-certs/
```

Then, the script `start-webserver` that would start your server:

```bash
#!/bin/bash

# Feching new certificates first
aws sync s3://bucket/path-to-certs/ /etc/my-certs/

function wait_until_change {
    inotifywait -r -e create,modify /etc/my-certs/
}

webserver start-in-background

while wait_until_change; do {
    webserver reload
} done
```

# Configuration

Environment variables:
- `S3_BUCKET`: Required. S3 bucket to store and retrieve the certificates (ex. `my-bucket`)
- `S3_PATH`: Required. S3 path to store and retrieve certificates (ex. `/certs/`)
- `RENEW_INTERVAL`: Optional. Number of hours between renewal checks.
- `VERBOSE`: Optional. If set with _any_ value, it will print more stuff.

CLI arguments: All certbot [arguments](https://certbot.eff.org/docs/using.html#certbot-command-line-options) are supported. `--non-interactive` is
added by default if not provided.

Also `sync` command is added to copy certificates from S3 to local storage.

*NOTE:* Any `-path` CLI argument might break the script.

## Certbot plugins
Only `--standalone` and `--dns-route-53` plugins are supported.

## Local testing
You can add `--dry-run` to the CLI arguments, but the validation still needs to happen. A workaround could be to use [ngrok](https://ngrok.com/) on your
local machine and create a short-lived certificate for the ngrok subdomain:

```bash
$ ngrok http 80 # Copy the ngrok domain (ex. xxxxxxx.ngrok.io)
$ sudo docker run --rm --name certbot-test \
    -e S3_BUCKET=my-bucket \
    -e S3_PATH=/my-certs/ \
    -e VERBOSE=true \
    -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
    -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
    -e "AWS_SECURITY_TOKEN=$AWS_SECURITY_TOKEN" \
    -p 80:80 \
    carlosmecha/certbot-s3 \
    certonly --standalone --non-interactive --agree-tos --email myemail@example.com --dry-run -d xxxxxxx.ngrok.io
Syncing S3 (s3://my-bucket/my-certs/ -> /etc/letsencrypt)
certbot certonly --standalone --non-interactive --agree-tos --email myemail@example.com --dry-run -d xxxxxxx.ngrok.io --non-interactive
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator standalone, Installer None
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for xxxxxxx.ngrok.io
Waiting for verification...
Cleaning up challenges
IMPORTANT NOTES:
 - The dry run was successful.
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
Syncing S3 (/etc/letsencrypt -> s3://my-bucket/my-certs/)
upload: ../../etc/letsencrypt/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/private_key.json to s3://my-bucket/my-certs/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/private_key.json
upload: ../../etc/letsencrypt/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/regr.json to s3://my-bucket/my-certs/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/regr.json
upload: ../../etc/letsencrypt/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/meta.json to s3://my-bucket/my-certs/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/meta.json

$ docker run --rm --name certbot-test \
    -e S3_BUCKET=my-bucket \
    -e S3_PATH=/my-certs/ \
    -e VERBOSE=true \
    -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
    -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
    -e "AWS_SECURITY_TOKEN=$AWS_SECURITY_TOKEN" \
    carlosmecha/certbot-s3 \
    renew --dry-run
Adding --non-interactive flag
Syncing S3 (s3://my-bucket/my-certs/ -> /etc/letsencrypt)
download: s3://my-bucket/my-certs/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/regr.json to ../../etc/letsencrypt/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/regr.json
download: s3://my-bucket/my-certs/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/meta.json to ../../etc/letsencrypt/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/meta.json
download: s3://my-bucket/my-certs/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/private_key.json to ../../etc/letsencrypt/accounts/acme-staging-v02.api.letsencrypt.org/directory/6a2e7b2bd3ff3977a0774d29fc4aa56a/private_key.json
$ certbot renew --dry-run --non-interactive
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
** DRY RUN: simulating 'certbot renew' close to cert expiry
**          (The test certificates below have not been saved.)

No renewals were attempted.
** DRY RUN: simulating 'certbot renew' close to cert expiry
**          (The test certificates above have not been saved.)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Syncing S3 (/etc/letsencrypt -> s3://my-bucket/my-certs/)
```

## Certbot-s3 and aws-cli
You can wrap `aws ecs run-task` in an script to make it a little bit more useful:
```bash
$ ./aws-certbot-s3 <certbot args>
```

Where `aws-certbot-s3` is:
```bash
#!/bin/bash

if [[  "$@" =~ "--standalone" ]]; then {
    exposePort='"portMappings": { "containerPort": 80, "hostPort": 80, "protocol": "tcp" },'
} fi

command="$(echo $@ | sed -e 's/\([a-zA-Z0-9_-]*\)/"\1",/g' -e 's/^\([a-zA-Z0-9_," -]*\),$/[ \1 ]/g')"
tmp=/tmp/certbot-overrides.json

cat << EOF > $tmp
{
  "containerOverrides": [
    {
      "name": "certbot",
      $exposePort
      "command": $command
    }
  ]
}
EOF

aws ecs run-task --cluster cluster --task-definition certbot-s3 --overrides file:///tmp/certbot-overrides.json
```

And the corresponding task definition:
```json
{
  "ipcMode": null,
  "executionRoleArn": null,
  "containerDefinitions": [
    {
      "dnsSearchDomains": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "certbot-logs",
          "awslogs-region": "us-west-2"
        }
      },
      "entryPoint": null,
      "portMappings": [],
      "command": null,
      "linuxParameters": null,
      "cpu": 64,
      "environment": [
        {
          "name": "S3_BUCKET",
          "value": "my-bucket"
        },
        {
          "name": "S3_PATH",
          "value": "my-certs/"
        }
      ],
      "ulimits": null,
      "dnsServers": null,
      "mountPoints": [],
      "workingDirectory": null,
      "secrets": null,
      "dockerSecurityOptions": null,
      "memory": 128,
      "memoryReservation": 64,
      "volumesFrom": [],
      "image": "ACCOUNT.dkr.ecr.us-west-2.amazonaws.com/certbot-s3:0.1",
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": true,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": null,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": false,
      "name": "certbot"
    }
  ],
  "placementConstraints": [],
  "memory": null,
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/certbot-task-role",
  "compatibilities": [
    "EC2"
  ],
  "taskDefinitionArn": "arn:aws:ecs:us-west-2:ACCOUNT:task-definition/certbot-s3:1",
  "family": "certbot-s3",
  "requiresAttributes": [
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.ecr-auth"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.task-iam-role"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.21"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
    }
  ],
  "pidMode": null,
  "requiresCompatibilities": [],
  "networkMode": null,
  "cpu": null,
  "revision": 1,
  "status": "ACTIVE",
  "volumes": []
}
```

# License

## Copyright 2019 Carlos Mecha

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
