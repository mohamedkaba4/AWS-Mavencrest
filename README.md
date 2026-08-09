# AWS E-Commerce Infrastructure

Production-style AWS infrastructure for the Mavencrest E-Commerce platform. It is provisioned with **Terraform**, tested and deployed through an automated **GitHub Actions CI/CD pipeline**.

The architecture uses EC2 Auto Scaling, an Application Load Balancer, immutable AMIs, and automated instance replacement to provide repeatable and highly available application deployments.

---

## Architecture

![AWS E-Commerce Architecture](assets/architecture.png)

### Core Infrastructure

- **Route 53** — DNS for `store.mavencrest.site`
- **Application Load Balancer** — distributes application traffic across healthy instances
- **EC2 Auto Scaling Group** — maintains application capacity across multiple Availability Zones
- **Launch Template** — defines the EC2 configuration and AMI used by the Auto Scaling Group
- **S3 / CloudFront** — object storage and CDN delivery for application assets
- **IAM Roles** — provides AWS access without storing credentials on EC2
- **SSM Parameter Store** — stores application configuration and sensitive values such as database connection strings
- **Terraform** — provisions and manages the AWS infrastructure

---

## CI/CD & Immutable Deployment

Application deployments use an immutable infrastructure workflow. Instead of updating application code directly on running EC2 instances, each deployment produces a new machine image containing the updated application.

```text
Application Repository
        │
        ▼
Developer Push
        │
        ▼
GitHub Actions — CI
        │
        ├── Install Dependencies
        ├── Generate Prisma Client
        ├── Build Storefront
        ├── Build Admin
        └── Validate Build
        │
        ▼
Packer
        │
        └── Build New AMI
        │
        ▼
AMI ID Published to SSM
        │
        ▼
Trigger AWS Infrastructure Repository
        │
        └── GitHub Actions Workflow
        │
        ▼
Terraform — CD
        │
        ├── terraform init
        ├── terraform validate
        ├── terraform plan
        └── terraform apply
        │
        ▼
Update Launch Template
        │
        ▼
EC2 Auto Scaling Group
        │
        └── Instance Refresh
        │
        ▼
New EC2 Instances
        │
        ├── ALB Health Checks
        └── Application Validation
        │
        ▼
Old Instances Terminated
```

### Deployment Flow

**1. Application change**

A push to the "deploy" branch triggers the GitHub Actions workflow.

**2. Build and validation**

The pipeline validates the application before creating a deployable image.

**3. Immutable AMI**

Packer creates a new Amazon Machine Image with the application and required runtime configuration.

**4. Infrastructure update**

The new AMI ID is passed into the infrastructure deployment process. Terraform updates the EC2 Launch Template with the new image.

**5. Rolling instance replacement**

The Auto Scaling Group performs an instance refresh, gradually replacing instances running the previous AMI.

**6. Health validation**

The Application Load Balancer routes traffic only to instances that pass the configured health checks. Once replacement instances are healthy, the old instances are terminated.

This approach avoids modifying running production instances and keeps deployments consistent and repeatable.

---

## Infrastructure as Code

Terraform manages the AWS infrastructure, including:

- Application Load Balancer
- Target Groups
- EC2 Launch Templates
- Auto Scaling
- IAM Roles and Policies
- Security Groups
- Route 53 DNS
- S3
- CloudFront
- SSM configuration

Infrastructure changes can be reviewed before deployment using a Terraform plan.

```bash
terraform plan -var-file="prod.tfvars" -out=prod.tfplan
```

Apply the reviewed plan:

```bash
terraform apply prod.tfplan
```

---

## Terraform State

Terraform state is stored remotely in S3 bucket rather than relying on local state files.

Remote state provides a representation for deployed infrastructure and prevents the infrastructure configuration from depending on a single workstation.

---

## Security

The deployment follows several AWS security practices:

- IAM roles instead of long-lived EC2 credentials
- GitHub Actions authentication through OIDC
- Sensitive application configuration stored in SSM Parameter Store
- Application instances accessed through the load-balancing layer
- Security Groups controlling network access
- HTTPS for public application traffic

---

## Deployment Model

```text
                  Route 53
                     │
                     ▼
            Application Load Balancer
                     │
              ┌──────┴──────┐
              ▼             ▼
           EC2 / AZ-A     EC2 / AZ-B
              │             │
              └──────┬──────┘
                     │
              Auto Scaling Group
                     │
               Launch Template
                     │
                 Latest AMI
```

The Auto Scaling Group maintains the desired application capacity and replaces unhealthy or outdated instances using the current Launch Template.

---

## Application

This repository contains the **AWS infrastructure and deployment architecture** for the Mavencrest E-Commerce platform.

The Storefront, Admin Portal, Prisma database layer, and application code are maintained separately in the E-Commerce application repository.
