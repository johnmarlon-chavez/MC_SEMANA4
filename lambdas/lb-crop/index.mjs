import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import sharp from 'sharp';

const s3 = new S3Client({});

export const handler = async (event) => {
  console.log('Evento SQS recibido:', JSON.stringify(event, null, 2));
  
  for (const record of event.Records) {
    // Parsear el evento S3 desde SQS
    let s3Info;
    try {
      const bodyObj = JSON.parse(record.body);
      if (bodyObj.Records && bodyObj.Records[0]) {
        s3Info = bodyObj.Records[0].s3;
      } else if (bodyObj.s3) {
        s3Info = bodyObj.s3;
      } else {
        console.error('Formato no reconocido:', bodyObj);
        continue;
      }
    } catch (e) {
      console.error('Error parseando body:', e.message);
      continue;
    }
    
    const bucket = s3Info.bucket.name;
    const key = decodeURIComponent(s3Info.object.key.replace(/\+/g, ' '));
    console.log(`Procesando: s3://${bucket}/${key}`);

    try {
      // Descargar imagen
      const response = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      const chunks = [];
      for await (const chunk of response.Body) chunks.push(chunk);
      const buffer = Buffer.concat(chunks);
      console.log(`Descargada: ${buffer.length} bytes, type: ${response.ContentType}`);

      // Procesar con sharp
      const circleShape = Buffer.from('<svg><circle cx="20" cy="20" r="20" /></svg>');
      const processed = await sharp(buffer)
        .resize(40, 40, { fit: 'cover' })
        .composite([{ input: circleShape, blend: 'dest-in' }])
        .png()
        .toBuffer();

      const newKey = key.replace('uploads/', 'processed/').replace(/\.[^.]+$/, '.png');
      console.log(`Subiendo a: ${newKey}`);

      await s3.send(new PutObjectCommand({
        Bucket: bucket,
        Key: newKey,
        Body: processed,
        ContentType: 'image/png'
      }));

      console.log(`✅ Exitoso: ${newKey}`);
    } catch (error) {
      console.error(`❌ Error en ${key}:`, error.message, error.stack);
      throw error;
    }
  }
  return { statusCode: 200, body: 'OK' };
};