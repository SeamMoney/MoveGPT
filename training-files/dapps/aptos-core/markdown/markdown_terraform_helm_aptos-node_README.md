# aptos-node

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

Aptos blockchain node deployment

**Homepage:** <https://aptoslabs.com/>

## Source Code

* <https://github.com/aptos-labs/aptos-core>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| chain.chain_id | int | `4` | Chain ID |
| chain.era | int | `1` | Bump this number to wipe the underlying storage |
| chain.name | string | `"testnet"` | Internal: name of the testnet to connect to |
| enablePrivilegedMode | bool | `false` | TEST ONLY: Enable running as root for profiling |
| fullnode.affinity | object | `{}` |  |
| fullnode.config | object | `{"full_node_networks":[{"network_id":"public","seeds":{}}]}` | Fullnode configuration. See NodeConfig https://github.com/aptos-labs/aptos-core/blob/main/config/src/config/mod.rs |
| fullnode.force_enable_telemetry | bool | `false` | Flag to force enable telemetry service (useful for forge tests) |
| fullnode.groups | list | `[{"name":"fullnode","replicas":1}]` | Specify fullnode groups by `name` and number of `replicas` |
| fullnode.nodeSelector | object | `{}` |  |
| fullnode.resources.limits.cpu | float | `15.5` |  |
| fullnode.resources.limits.memory | string | `"26Gi"` |  |
| fullnode.resources.requests.cpu | int | `15` |  |
| fullnode.resources.requests.memory | string | `"26Gi"` |  |
| fullnode.rust_log | string | `"info"` | Log level for the fullnode |
| fullnode.storage.class | string | `nil` | Kubernetes storage class to use for fullnode persistent storage |
| fullnode.storage.size | string | `"2048Gi"` | Size of fullnode persistent storage |
| fullnode.tolerations | list | `[]` |  |
| haproxy.affinity | object | `{}` |  |
| haproxy.config.send_proxy_protocol | bool | `false` | Whether to send Proxy Protocol v2 |
| haproxy.enabled | bool | `true` | Enable HAProxy deployment in front of validator and fullnodes |
| haproxy.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy to use for HAProxy images |
| haproxy.image.repo | string | `"haproxy"` | Image repo to use for HAProxy images |
| haproxy.image.tag | string | `"2.2.29@sha256:8019a233a37045a27970dbc990e9ea485799200c40f658e4620b7fdf55641a3c"` | Image tag to use for HAProxy images |
| haproxy.limits.validator.connectionsPerIPPerMin | int | `12` | Limit the number of connections per IP address per min |
| haproxy.limits.validator.maxBytesOutRate10sec | int | `134217728` |  |
| haproxy.limits.validator.rateLimitSession | int | `256` |  |
| haproxy.limits.validator.tcpBufSize | int | `524288` |  |
| haproxy.nodeSelector | object | `{}` |  |
| haproxy.replicas | int | `1` | Number of HAProxy replicas |
| haproxy.resources.limits.cpu | int | `4` |  |
| haproxy.resources.limits.memory | string | `"8Gi"` |  |
| haproxy.resources.requests.cpu | int | `4` |  |
| haproxy.resources.requests.memory | string | `"8Gi"` |  |
| haproxy.tls_secret | string | `nil` | Name of the Kubernetes TLS secret to use for HAProxy |
| haproxy.tolerations | list | `[]` |  |
| imageTag | string | `"devnet"` | Default image tag to use for all validator and fullnode images |
| labels | string | `nil` |  |
| loadTestGenesis | bool | `false` | Load test-data for starting a test network |
| manageImages | bool | `true` | If true, helm will always override the deployed image with what is configured in the helm values. If not, helm will take the latest image from the currently running workloads, which is useful if you have a separate procedure to update images (e.g. rollout) |
| multicluster | object | `{"enabled":false,"targetClusters":["cluster1","cluster2","cluster3"]}` | Options for multicluster mode. This is *experimental only*. |
| numFullnodeGroups | int | `1` | Total number of fullnode groups to deploy |
| numValidators | int | `1` | Number of validators to deploy |
| overrideNodeConfig | bool | `false` | Specify validator and fullnode NodeConfigs via named ConfigMaps, rather than the generated ones from this chart. |
| service.domain | string | `nil` | If set, the base domain name to use for External DNS |
| service.fullnode.enableMetricsPort | bool | `true` | Enable the metrics port on fullnodes |
| service.fullnode.enableRestApi | bool | `true` | Enable the REST API on fullnodes |
| service.fullnode.external.type | string | `"LoadBalancer"` | The Kubernetes ServiceType to use for fullnodes' HAProxy |
| service.fullnode.externalTrafficPolicy | string | `"Local"` | The externalTrafficPolicy for the fullnode service |
| service.fullnode.internal.headless | bool | `false` |  |
| service.fullnode.internal.type | string | `"ClusterIP"` | The Kubernetes ServiceType to use for fullnodes |
| service.fullnode.loadBalancerSourceRanges | string | `nil` | If set and if the ServiceType is LoadBalancer, allow traffic to fullnodes from these CIDRs |
| service.validator.enableMetricsPort | bool | `true` | Enable the metrics port on the validator |
| service.validator.enableRestApi | bool | `true` | Enable the REST API on the validator |
| service.validator.external.type | string | `"LoadBalancer"` | The Kubernetes ServiceType to use for validator's HAProxy |
| service.validator.externalTrafficPolicy | string | `"Local"` | The externalTrafficPolicy for the validator service |
| service.validator.internal.headless | bool | `false` |  |
| service.validator.internal.type | string | `"ClusterIP"` | The Kubernetes ServiceType to use for validator |
| service.validator.loadBalancerSourceRanges | string | `nil` | If set and if the ServiceType is LoadBalancer, allow traffic to validators from these CIDRs |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `nil` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| validator.affinity | object | `{}` |  |
| validator.config | object | `{}` | Validator configuration. See NodeConfig https://github.com/aptos-labs/aptos-core/blob/main/config/src/config/mod.rs |
| validator.enableNetworkPolicy | bool | `true` | Lock down network ingress and egress with Kubernetes NetworkPolicy |
| validator.force_enable_telemetry | bool | `false` | Flag to force enable telemetry service (useful for forge tests) |
| validator.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy to use for validator images |
| validator.image.repo | string | `"aptoslabs/validator"` | Image repo to use for validator images |
| validator.image.tag | string | `nil` | Image tag to use for validator images. If set, overrides `imageTag` |
| validator.name | string | `nil` | Internal: name of your validator for use in labels |
| validator.nodeSelector | object | `{}` |  |
| validator.remoteLogAddress | string | `nil` | Address for remote logging. See `logger` helm chart |
| validator.resources.limits.cpu | float | `15.5` |  |
| validator.resources.limits.memory | string | `"26Gi"` |  |
| validator.resources.requests.cpu | int | `15` |  |
| validator.resources.requests.memory | string | `"26Gi"` |  |
| validator.rust_log | string | `"info"` | Log level for the validator |
| validator.storage.class | string | `nil` | Kubernetes storage class to use for validator persistent storage |
| validator.storage.size | string | `"2048Gi"` | Size of validator persistent storage |
| validator.tolerations | list | `[]` |  |

## Resource Descriptions

Below is a list of the Kubernetes resources created by this helm chart.

The resources created by this helm chart will be prefixed with the helm release name. Below, they are denoted by
the `<RELEASE_NAME>` prefix.

StatefulSets:
* `<RELEASE_NAME>-aptos-node-0-validator` - The validator StatefulSet
* `<RELEASE_NAME>-aptos-node-0-fullnode-e<ERA>` - The fullnode StatefulSet

Deployments:
* `<RELEASE_NAME>-aptos-node-0-validator` - The HAProxy deployment

PersistentVolumeClaim:
* `<RELEASE_NAME>-0-validator-e<ERA>` - The validator PersistentVolumeClaim
* `fn-<RELEASE_NAME>-0-fullnode-e<ERA>-0` - The fullnode PersistentVolumeClaim. Note the difference in naming scheme between valdiator and fullnode PVC, which is due to the fact that you can spin up multiple fullnodes, but only a single validator.

Services:
* `<RELEASE_NAME>-aptos-node-0-validator-lb` - Inbound load balancer service that routes to the validator
* `<RELEASE_NAME>-aptos-node-0-fullnode-lb` - Inbound load balancer service that routes to the fullnode

ConfigMaps:
* `<RELEASE_NAME>-0` - The validator and fullnode NodeConfigs
* `<RELEASE_NAME>-0-haproxy` - The HAProxy configuration

NetworkPolicies:
* `<RELEASE_NAME>-0-validator` - The validator NetworkPolicy, which controls network access to the validator pods

ServiceAccounts:
* [optional] `<RELEASE_NAME>` - The default service account
* `<RELEASE_NAME>-validator` - The validator service account
* `<RELEASE_NAME>-fullnode` - The fullnode service account

[optional] PodSecurityPolicy:
* `<RELEASE_NAME>` - The default PodSecurityPolicy for validators and fullnodes
* `<RELEASE_NAME>-haproxy` - The PodSecurityPolicy for HAProxy

## Common Operations

### Check Pod Status

```
$ kubectl get pods
```

You should see at least `1/1` replicas running for the validator, fullnode, and HAProxy. If there are any restarts, you should see it in this view.

To see more details about a singular pod, you can describe it:

```
$ kubectl describe pod <POD_NAME>
```

### Check the Pod Logs

```
$ kubectl logs <POD_NAME>
```

### Check all services

```
$ kubectl get services
```

By default, the services are `LoadBalancer` type, which means that they will be accessible from the outside world. Depending on your kubernetes deployment/cloud, the public IP or DNS information will be displayed.

### Scale Down Workloads

If you want to temporarily remove some of the workloads, you can scale them down.
```
# scale down the validator
kubectl scale statefulset <STS_NAME> --replicas=0
```

## Advanced Options

### Testnet Mode (Multiple Validators and Fullnodes)

For testing purposes, you may deploy multiple validators into the same cluster via `.Values.numValidators`. The naming convention is `<RELEASE_NAME>-aptos-node-<INDEX>-validator`, where `<INDEX>` is the index of the validator. Note that for each validator, you must provide genesis ConfigMaps for each, of the name: `<RELEASE_NAME>-<INDEX>-genesis-e<ERA>`.
You may also deploy multiple fullnodes into the cluster via `.Values.numFullnodeGroups` and `.Values.fullnode.groups`. Each validator can have multiple fullnode groups, each with multiple replicas. The total number of fullnode groups can be limited via `.Values.numFullnodeGroups`.

### Era

The `.Values.chain.era` is a number that is incremented every time the validator's storage is wiped. This is ueful for testnets when the network is wiped.

### Privileged Mode

For debugging purposes, it's sometimes useful to run the validator as root (privileged mode). This is enabled by `.Values.enablePrivilegedMode`.

