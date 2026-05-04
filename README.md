# Image Processor

Sistema de procesamiento de imágenes serverless con AWS Lambda, S3, SQS y API Gateway.

## Arquitectura

- **lb-upload**: Lambda que recibe imágenes vía API Gateway y las almacena en S3 (`uploads/`)
- **lb-crop**: Lambda disparada por SQS que procesa imágenes (resize 40x40 + máscara circular) y las guarda en S3 (`processed/`)
- **S3**: Bucket de almacenamiento con prefijos `uploads/` y `processed/`
- **SQS**: Cola que encola eventos de subida de imágenes
- **API Gateway**: endpoint HTTP para recibir las imágenes

## Despliegue

### Entorno DEV
```bash
cd terraform
terraform init
terraform workspace new dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars" -auto-approve
```

### Entorno QA
```bash
cd terraform
terraform workspace new qa
terraform plan -var-file="qa.tfvars"
terraform apply -var-file="qa.tfvars" -auto-approve
```

### Entorno PROD
```bash
cd terraform
terraform workspace new prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars" -auto-approve
```

## Uso

Obtén la URL de la API desde la salida de Terraform:

```bash
curl -X POST https://TU_API_URL_AQUI/upload \
  -H "Content-Type: image/png" \
  --data-binary "@/ruta/a/tu/foto.png"
```

Soporta: `image/jpeg`, `image/png`, `image/gif`, `image/webp` .

## Limpieza

```bash
terraform destroy -var-file="<entorno>.tfvars" -auto-approve
```

Reemplaza `<entorno>` por `dev`, `qa` o `prod`.
