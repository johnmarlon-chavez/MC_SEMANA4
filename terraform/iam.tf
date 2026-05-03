# --- POLITICA DE ASUNCION DE ROL ( para las Lambdas) ---

resource "aws_iam_role" "lambda_common_role" {
  name = "lambda-base-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = { Owner = "MarlonChavez" }
}

# --- PERMISOS BASICOS: LOGS Y VPC ---
# Permite a las Lambdas crear logs y conectarse a la red privada (VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_common_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# --- PERMISOS ESPECÍFICOS PARA LAMBDA UPLOAD ---
resource "aws_iam_policy" "upload_policy" {
  name        = "upload-lambda-policy-${var.environment}"
  description = "Habilita la subida de archivos al directorio de carga."
  tags        = { Owner = "MarlonChavez" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = ["${aws_s3_bucket.images.arn}/uploads/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_attach" {
  role       = aws_iam_role.lambda_common_role.name
  policy_arn = aws_iam_policy.upload_policy.arn
}

# --- PERMISOS ESPECÍFICOS PARA LAMBDA CROP ---
resource "aws_iam_policy" "crop_policy" {
  name        = "crop-lambda-policy-${var.environment}"
  description = "Permisos para procesar imágenes desde S3 y gestionar colas SQS."
  tags        = { Owner = "MarlonChavez" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.images.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.images.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [aws_sqs_queue.image_queue.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crop_attach" {
  role       = aws_iam_role.lambda_common_role.name
  policy_arn = aws_iam_policy.crop_policy.arn
}