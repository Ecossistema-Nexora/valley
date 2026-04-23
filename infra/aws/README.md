# Terraform AWS

Provisiona:

- VPC com subnets públicas, privadas e de banco
- EKS com IRSA habilitado
- RDS PostgreSQL privado
- ElastiCache Redis gerenciado
- ECR para imagens
- S3 para artefatos

Nao provisiona MongoDB gerenciado. O Valley continua hibrido, entao `MONGODB_URI` deve apontar para Atlas, DocumentDB ou outro cluster Mongo operado fora deste modulo Terraform.

## Uso

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Depois do apply

1. Atualize o kubeconfig:
   ```bash
   aws eks update-kubeconfig --region <AWS_REGION> --name <CLUSTER_NAME>
   ```
2. Instale addons do cluster.
3. Ajuste os secrets, incluindo `MONGODB_URI`, e publique o chart Helm.
