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
  const inputKey = decodeURIComponent(
    event.Records[0].s3.object.key.replace(/\+/g, " ")
  );
  const filename = inputKey.split("/").pop();
  const outputBucket = config.buckets.output;
  const outputKey = filename;

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

    const greyscaleImageBuffer = await sharp(imageBuffer)
      .greyscale()
      .toBuffer();

    await s3Client.send(
      new PutObjectCommand({
        Bucket: outputBucket,
        Key: outputKey,
        Body: greyscaleImageBuffer,
        ContentType: response.ContentType || "image/jpeg",
      })
    );

    inspector.addAttribute("inputBucket", inputBucket);
    inspector.addAttribute("outputBucket", outputBucket);
    inspector.addAttribute("inputKey", inputKey);
    inspector.addAttribute("outputKey", outputKey);
    inspector.addAttribute("message", "Image greyscaled successfully");

    inspector.inspectAllDeltas();
    const result = inspector.finish();
    console.log(JSON.stringify(result));
    return result;
  } catch (error) {
    console.error("Error:", error);

    inspector.addAttribute("message", "Error greyscaling image");
    inspector.addAttribute("error", error.message);

    inspector.inspectAllDeltas();
    const result = inspector.finish();
    console.log(JSON.stringify(result));
    return result;
  }
};
