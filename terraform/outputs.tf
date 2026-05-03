output "api_url" {
  description = "Punto de enlace de la API para carga de imagenes"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/upload"
}

output "s3_bucket_name" {
  description = "Identificador del bucket de almacenamiento"
  value       = aws_s3_bucket.images.id
}

output "sqs_queue_url" {
  description = "Dirección de la cola de mensajería"
  value       = aws_sqs_queue.image_queue.id
}