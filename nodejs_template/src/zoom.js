const {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} = require("@aws-sdk/client-s3");
const sharp = require("sharp");
const Inspector = require("./Inspector");
const config = require("./config");

const s3Client = new S3Client();

exports.handler = async (event) => {
  const inspector = new Inspector();
  inspector.inspectAll();

  const inputBucket = event.Records[0].s3.bucket.name;
  const inputKey = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  const filename = inputKey.split('/').pop();
  
  // Output bucket from config
  const outputBucket = config.buckets.base;
  const outputKey = config.buckets.stage2 + filename;
  
  try {
    const response = await s3Client.send(
      new GetObjectCommand({
        Bucket: inputBucket,
        Key: inputKey,
      })
    );

    const chunks = [];
    for await (const chunk of response.Body) {
      chunks.push(chunk);
    }
    const imageBuffer = Buffer.concat(chunks);

    const metadata = await sharp(imageBuffer).metadata();
    const originalWidth = metadata.width;
    const originalHeight = metadata.height;

    const cropWidth = Math.round(originalWidth * 0.5);
    const cropHeight = Math.round(originalHeight * 0.5);
    const left = Math.round((originalWidth - cropWidth) / 2);
    const top = Math.round((originalHeight - cropHeight) / 2);

    const zoomedImageBuffer = await sharp(imageBuffer)
      .extract({ left, top, width: cropWidth, height: cropHeight })
      .resize(originalWidth, originalHeight)
      .toBuffer();

    await s3Client.send(
      new PutObjectCommand({
        Bucket: outputBucket,
        Key: outputKey,
        Body: zoomedImageBuffer,
        ContentType: response.ContentType || "image/jpeg",
      })
    );

    inspector.addAttribute("inputBucket", inputBucket);
    inspector.addAttribute("outputBucket", outputBucket);
    inspector.addAttribute("inputKey", inputKey);
    inspector.addAttribute("outputKey", outputKey);
    inspector.addAttribute("message", "Image zoomed successfully");

    inspector.inspectAllDeltas();
    const result = inspector.finish();
    console.log(JSON.stringify(result));
    return result;

  } catch (error) {
    console.error("Error:", error);

    inspector.addAttribute("message", "Error zooming image");
    inspector.addAttribute("error", error.message);

    inspector.inspectAllDeltas();
    const result = inspector.finish();
    console.log(JSON.stringify(result));
    return result;
  }
};
