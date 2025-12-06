const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');
const Inspector = require('./Inspector');
const config = require('./config');

const s3Client = new S3Client();

exports.handler = async (event) => {
  const inspector = new Inspector();
  inspector.inspectAll();
  
  const inputBucket = event.Records[0].s3.bucket.name;
  const inputKey = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  const filename = inputKey.split('/').pop();
  const outputBucket = config.buckets.stage1;
  const outputKey = filename;
  
  try {
    const response = await s3Client.send(new GetObjectCommand({
      Bucket: inputBucket,
      Key: inputKey,
    }));
    
    const chunks = [];
    for await (const chunk of response.Body) {
      chunks.push(chunk);
    }
    const imageBuffer = Buffer.concat(chunks);
    
    const rotatedImageBuffer = await sharp(imageBuffer)
      .rotate(180)
      .toBuffer();
    
    await s3Client.send(new PutObjectCommand({
      Bucket: outputBucket,
      Key: outputKey,
      Body: rotatedImageBuffer,
      ContentType: response.ContentType || 'image/jpeg',
    }));
    
    inspector.addAttribute('inputBucket', inputBucket);
    inspector.addAttribute('outputBucket', outputBucket);
    inspector.addAttribute('inputKey', inputKey);
    inspector.addAttribute('outputKey', outputKey);
    inspector.addAttribute('message', 'Image rotated successfully');
    
    inspector.inspectAllDeltas();
    return inspector.finish();
    
  } catch (error) {
    console.error('Error:', error);
    
    inspector.addAttribute('message', 'Error rotating image');
    inspector.addAttribute('error', error.message);
    
    inspector.inspectAllDeltas();
    return inspector.finish();
  }
};
