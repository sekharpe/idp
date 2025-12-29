# CNOE Platform Documentation

Welcome to the CNOE (Cloud Native Operational Excellence) Internal Developer Portal documentation.

## Quick Links

- [Platform Overview](overview.md)
- [Getting Started Guide](getting-started.md)
- [Service Catalog](catalog.md)
- [Templates](templates.md)
- [Operations](operations.md)

## Platform Components

### ArgoCD (GitOps)
GitOps-based continuous delivery for Kubernetes. All platform and application configurations are managed declaratively in Git.

**Access:** Port 8080/argocd

### Backstage (Ready for Deployment)
Infrastructure is prepared for Backstage deployment. Database, storage, and configurations are ready.

**Status:** Infrastructure Ready

### Kubernetes (AKS)
Single-node cost-optimized cluster for dev/MVP environment.

**Configuration:**
- Node Size: Standard_B2s (2 vCPU, 4GB RAM)
- Node Count: 1
- Environment: Development

## Architecture

```
┌─────────────────────────────────────────────────┐
│           CNOE Platform Portal (8081)           │
│                                                 │
│  ┌────────────┐  ┌──────────┐  ┌────────────┐ │
│  │  Service   │  │  GitOps  │  │    Docs    │ │
│  │  Catalog   │  │ (ArgoCD) │  │            │ │
│  └────────────┘  └──────────┘  └────────────┘ │
└─────────────────────────────────────────────────┘
                      ▼
         ┌─────────────────────────┐
         │   API Gateway (8080)    │
         └─────────────────────────┘
                      ▼
         ┌─────────────────────────┐
         │    Kubernetes (AKS)     │
         │    Single Node Cluster   │
         └─────────────────────────┘
```

## Cost Optimization

This dev environment is optimized for minimal cost:

- **Single Node:** 1x Standard_B2s (~$30/month)
- **ACR:** Basic SKU (~$5/month)
- **Key Vault:** Standard SKU (~$0.03/10k operations)
- **Log Analytics:** Pay-as-you-go
- **Estimated Total:** ~$40-50/month

## Next Steps

1. Deploy infrastructure with Terraform
2. Bootstrap ArgoCD
3. Deploy platform services
4. (Optional) Deploy Backstage when ready

## Support

For issues or questions, contact your platform engineering team.
