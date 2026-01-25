Dear Users,

We are excited to announce the first release of the bot-project! This release marks a significant milestone in our journey to provide multi-arch builds and support for Kubernetes installations.

To make it easier to deploy and manage, we have created a Helm chart that can be used to install and configure the application on Kubernetes clusters. The Helm chart includes all the necessary configurations and dependencies to get you up and running quickly.

In addition to the Helm chart, we have also created a GitHub release that includes the chart package, along with detailed release notes and instructions on how to deploy and use bot-project. This release is available now on our GitHub repository, and we encourage you to check it out.

**Release URL:** ${RELEASE_URL}

**Helm Chart Package:** ${RELEASE_URL}

## Installation Instructions

To get started, simply download the Helm chart package from the GitHub release page and use it to install the application on your Kubernetes cluster.

### Prerequisites

1. Kubernetes cluster (1.20+)
2. Helm 3.x installed
3. kubectl configured

### Quick Start

1. Create namespace and secret:
```bash
kubectl create namespace kbot
kubectl create secret generic kbot-secret \
    --from-literal=tele-token=<YOUR_TELEGRAM_TOKEN> \
    --namespace=kbot
```

2. Install using Helm:
```bash
${INSTALL_INSTRUCTION}
```

3. Verify installation:
```bash
kubectl get all -n kbot
kubectl logs -l app.kubernetes.io/name=kbot -n kbot
```

### What's Included

- **Helm Chart Version:** ${CHART_VERSION}
- **Release Tag:** ${RELEASE_TAG}
- **Multi-arch Docker Image:** Supports linux/amd64 and linux/arm64
- **Kubernetes Deployment:** Ready-to-use Helm chart with all necessary configurations
- **Namespace Isolation:** Deploys to dedicated `kbot` namespace

### Features

- Easy deployment with Helm
- Multi-architecture support (amd64, arm64)
- Kubernetes Secret integration for secure token management
- Production-ready configuration
- Comprehensive documentation

You can also view the release notes for more information on new features, bug fixes, and other changes included in this release.

Thank you for your support and happy deploying!

Best regards!
