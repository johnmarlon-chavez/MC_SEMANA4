import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import Busboy from "busboy";
import { v4 as uuidv4 } from "uuid";

const s3 = new S3Client({ region: "us-east-1" });
const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];
const MAX_SIZE = 10 * 1024 * 1024;

export const handler = async (event) => {
  try {
    const contentType = event.headers?.["content-type"] || event.headers?.["Content-Type"] || "";
    let fileBuffer, fileName, mimeType;

    if (contentType.includes("multipart/form-data")) {
      const result = await parseMultipart(event, contentType);
      fileBuffer = result.buffer;
      fileName   = result.name;
      mimeType   = result.mimeType;
    } else {
      const body  = JSON.parse(event.body);
      fileBuffer  = Buffer.from(body.file, "base64");
      fileName    = body.filename || "upload";
      mimeType    = body.mimeType || "image/jpeg";
    }

    if (!ALLOWED_TYPES.includes(mimeType))
      return { statusCode: 400, body: JSON.stringify({ error: "Tipo no permitido. Usa jpg, png, gif o webp." }) };

    if (fileBuffer.length > MAX_SIZE)
      return { statusCode: 400, body: JSON.stringify({ error: "Archivo demasiado grande. Máximo 10 MB." }) };

    const key = `${process.env.UPLOAD_PREFIX}${uuidv4()}-${fileName}`;
    await s3.send(new PutObjectCommand({
      Bucket:      process.env.S3_BUCKET,
      Key:         key,
      Body:        fileBuffer,
      ContentType: mimeType,
    }));

    return { statusCode: 200, body: JSON.stringify({ message: "Imagen subida correctamente", key }) };
  } catch (err) {
    console.error("Error en upload-lambda:", err);
    return { statusCode: 500, body: JSON.stringify({ error: "Error interno del servidor" }) };
  }
};

function parseMultipart(event, contentType) {
  return new Promise((resolve, reject) => {
    const bb     = Busboy({ headers: { "content-type": contentType } });
    let buffer   = [], name = "upload", mimeType = "image/jpeg";
    bb.on("file", (field, file, info) => {
      mimeType = info.mimeType;
      name     = info.filename || name;
      file.on("data", (d) => buffer.push(d));
    });
    bb.on("finish", () => resolve({ buffer: Buffer.concat(buffer), name, mimeType }));
    bb.on("error", reject);
    bb.write(Buffer.from(event.body, event.isBase64Encoded ? "base64" : "utf8"));
    bb.end();
  });
}