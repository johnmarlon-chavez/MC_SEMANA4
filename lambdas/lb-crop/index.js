import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import sharp from 'sharp';

const s3 = new S3Client({});

export const handler = async (event) => {
    for (const record of event.Records) {
        const s3Event = JSON.parse(record.body).Records[0].s3;
        const bucket = s3Event.bucket.name;
        const key = decodeURIComponent(s3Event.object.key.replace(/\+/g, ' '));

        try {
            const response = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
            const chunks = [];
            for await (const chunk of response.Body) chunks.push(chunk);
            const buffer = Buffer.concat(chunks);

            
            const circleShape = Buffer.from(
                '<svg><circle cx="20" cy="20" r="20" /></svg>'
            );

            const processed = await sharp(buffer)
                .resize(40, 40, { fit: 'cover' })
                .composite([{
                    input: circleShape,
                    blend: 'dest-in'
                }])
                .png()
                .toBuffer();

            const newKey = key.replace('uploads/', 'processed/').replace(/\.[^.]+$/, '.png');

            await s3.send(new PutObjectCommand({
                Bucket: bucket,
                Key: newKey,
                Body: processed,
                ContentType: 'image/png'
            }));

            console.log(`Procesado exitoso: ${newKey}`);
        } catch (error) {
            console.error(`Error procesando ${key}:`, error);
            throw error; 
        }
    }
};