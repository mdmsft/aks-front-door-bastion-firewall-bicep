# Multi-tenant AKS with Azure Front Door (CDN) in front of Azure Firewall with TLS and internal load balancer

## Prerequisites
* `parameters.json`
    ```json
    {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "workload": {
                "value": "contoso"
            },
            "environment": {
                "value": "dev"
            },
            "addressPrefix": {
                "value": "172.17.0.0/22" // fits 4 /24 subnets
            },
            "principalId": {
                "value": "<your-AAD-object-id>"
            },
            "dnsZoneId": {
                "value": "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.Network/dnszones/<dns-zone-name>"
            }
        }
    }
    ```
* `certificate.pfx` X.509 wildcard certificate, e.g. `*.<dns-zone-name>`

## Azure resources deployment
```sh
outputs=`az deployment sub create -l <region> -f main.bicep -p parameters.json -n <name> | jq '.outputs'`
```

## Get AKS credentials (`azCliCommandText`)

## NGINX ingress controller installation
```sh
loadBalancerIP=`echo $outputs | jq -r '.internalLoadBalancerIpAddress'`
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.service.loadBalancerIP=$loadBalancerIP --set controller.service.annotations."service\.beta\.kubernetes\.io\/azure-load-balancer-internal"="true"
```

## Kubernetes manifests deployment
```sh
cd k8s
hostname=`echo $outputs | jq -r '.hostname'`
HOSTNAME=$hostname kubectl apply -k tailspin
HOSTNAME=$hostname kubectl apply -k wingtip
```