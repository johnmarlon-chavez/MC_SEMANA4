# AWS Procesador de Imágenes Serverless

Implementación de una arquitectura serverless escalable en AWS mediante IaC para soportar un ciclo de desarrollo completo. El sistema recibe imágenes vía API, las almacena en S3 y procesa versiones optimizadas de forma asíncrona usando SQS, con despliegue multi-entorno (dev/qa/prod) y gestión automatizada del ciclo de vida de los recursos.

## Objetivo del Proyecto

Desplegar una solución serverless en AWS que automatice el ciclo de vida de las imágenes: ingesta vía API Gateway con validación de formatos y tamaño, persistencia en S3 con políticas de lifecycle, y procesamiento asíncrono mediante SQS (resize a 40×40 píxeles con máscara circular usando sharp). Todo gestionado como Infraestructura como Código con Terraform, utilizando workspaces para entornos aislados (dev/qa/prod), roles IAM de mínimo privilegio, VPC endpoints para conectividad privada, y eliminación automática de recursos para optimización de costos.

---

## Tabla de Contenidos

```
Cliente → API Gateway (HTTP) → Lambda Upload → S3 (uploads/)
                                              ↓
                                         Evento S3
                                              ↓
                                            SQS
                                              ↓
                                         Lambda Crop
                                              ↓
                                         S3 (processed/)
```

### Componentes

- **API Gateway (HTTP)** - Endpoint REST para subida de imágenes
- **Lambda upload** - Valida y persiste imágenes (256MB RAM, 30s timeout)
- **S3 Bucket** - Almacenamiento con políticas de lifecycle:
  - `uploads/` → Expiración a 30 días
  - `processed/` → Expiración a 90 días
- **SQS** - Cola de mensajes para decoupling (retries: 3, DLQ habilitada)
- **Lambda crop** - Procesamiento con sharp (512MB RAM, 60s timeout):
  - Resize: 40×40 píxeles con `cover`
  - Máscara circular vía SVG mask + blend `dest-in`
  - Output: PNG optimizado
- **VPC Endpoints** - Conectividad privada para S3 y SQS

## Stack Tecnológico

### Runtime
- Node.js 20.x (ES modules)
- AWS Lambda

### Dependencias
- `@aws-sdk/client-s3` - Cliente AWS S3 v3
- `busboy` - Parseo multipart/form-data
- `uuid` - Generación de identificadores
- `sharp` - Procesamiento de imágenes (binario nativo)

### Infraestructura
- Terraform ≥1.0
- AWS Provider ~> 5.0
- Recursos: S3, SQS, Lambda, API Gateway HTTP, VPC, CloudWatch

## Despliegue

### Pre-requisitos
- Terraform ≥1.0
- AWS CLI configurada
- Node.js 20.x

### Inicialización
```bash
cd terraform
terraform init
```

### Entornos

#### Desarrollo (DEV)
```bash
cd terraform
terraform workspace select dev || terraform workspace new dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

#### QA
```bash
cd terraform
terraform workspace select qa || terraform workspace new qa
terraform plan -var-file="qa.tfvars"
terraform apply -var-file="qa.tfvars"
```

#### Producción (PROD)
```bash
cd terraform
terraform workspace select prod || terraform workspace new prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Uso

### Subir Imagen
```bash
curl -X POST https://{api-id}.execute-api.us-east-1.amazonaws.com/upload \
  -F "file=@/ruta/imagen.png"
```

### Respuesta Exitosa
```json
{
  "message": "Imagen subida correctamente",
  "key": "uploads/550e8400-e29b-41d4-a716-446655440000-imagen.png"
}
```

### Obtener URL de la API
```bash
cd terraform
terraform output api_url
```

## Estructura del Proyecto

```
.
 lambdas/
    lb-upload/              # Lambda ingesta (multipart → S3)
       index.mjs          # Handler ES modules
       package.json       # Dependencias (busboy, uuid, aws-sdk)
    lb-crop/                # Lambda procesamiento (SQS → sharp → S3)
        index.mjs          # Handler ES modules
        package.json       # Dependencias (sharp, aws-sdk)
        node_modules/      # Dependencias nativas
 terraform/
     providers.tf           # Configuración providers
     variables.tf           # Variables globales
     dev.tfvars             # Variables entorno DEV
     qa.tfvars              # Variables entorno QA
     prod.tfvars            # Variables entorno PROD
     networking.tf          # VPC, Subnets, Security Groups
     iam.tf                 # Roles y políticas IAM
     storage and queue.tf   # S3, SQS, Lifecycle, Notifications
     lb-upload.tf           # Lambda upload
     lb-crop.tf             # Lambda crop + SQS trigger
     api_gateway.tf         # API Gateway HTTP
     outputs.tf             # Outputs: api_url, s3, sqs
```

## Variables de Entorno

### upload-lambda
- `S3_BUCKET` - Bucket destino (Ej: `image-processor-{env}-images-*`)
- `UPLOAD_PREFIX` - Prefijo S3 (`uploads/`)

### crop-lambda
- `S3_BUCKET` - Bucket origen/destino
- `PROCESSED_PREFIX` - Prefijo S3 (`processed/`)

## Límites y Validaciones

### Restricciones Lambda Upload
- Formatos permitidos: JPEG, PNG, GIF, WebP
- Tamaño máximo: 10 MB
- Timeout: 30 segundos
- Memoria: 256 MB

### Restricciones Lambda Crop
- Timeout: 60 segundos
- Memoria: 512 MB
- Procesamiento: Resize 40×40 + máscara circular
- Output: PNG optimizado

### SQS
- Retries automáticos: 3 intentos
- Dead Letter Queue: Habilitada
- Visibility timeout: 360s

## Limpieza

```bash
cd terraform
terraform destroy -var-file="dev.tfvars" -auto-approve
```

**Nota:** Repetir para qa y prod cambiando el archivo de variables.

## Observabilidad

### Logging
- **CloudWatch Groups:**
  - `/aws/lambda/upload-lambda-{env}`
  - `/aws/lambda/crop-lambda-{env}`
  - `/aws/apigateway/image-processor-{env}`

### Metrics
- Invocaciones Lambda
- Errores y timeout
- Duración promedio
- Tamaño payload S3

### Trazas
- JSON estructurado en logs Lambda
- Contexto: requestId, key, bucket

## Seguridad

### Credenciales
- No incluir credenciales AWS en código fuente
- Usar variables de entorno o perfiles IAM
- Rotación regular de access keys

### Tags Obligatorios
Todos los recursos incluyen:
- `Project: ImageProcessor`
- `Environment: {dev|qa|prod}`
- `Owner: MarlonChavez`

### Políticas de Seguridad
- Bucket S3 con bloqueo de acceso público
- VPC endpoints para conectividad privada
- IAM roles con mínimo privilegio
- Lifecycle policies para eliminación automática
- Encriptación server-side (S3) habilitada

---

## Política de Costo Cero

**Evidencia obligatoria de destrucción total tras pruebas:**

```bash
terraform destroy -var-file="<entorno>.tfvars" -auto-approve
```

Reemplazar `<entorno>` por: `dev`, `qa`, o `prod`.

**Verificación:**
- Confirmar salida de `terraform destroy`
- Revisar consola AWS que no queden recursos
- Bucket S3 deben estar vacíos antes de destruir