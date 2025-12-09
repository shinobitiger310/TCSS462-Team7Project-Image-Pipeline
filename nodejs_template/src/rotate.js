/**
 * Lambda Function: Rotate Image 180 Degrees
 * 
 * Trigger: S3 PUT event on input bucket
 * Input: Image from input bucket
 * Output: Rotated image to stage1 bucket
 * 
 * SETUP:
 * 1. Update bucket names in config.js
 * 2. Create Lambda function with Node.js 20.x runtime
 * 3. Set timeout to 90 seconds, memory to 1024 MB
 * 4. Add S3 trigger for PUT events on your input bucket
 * 5. Add AmazonS3FullAccess permission to Lambda role
 */

const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');
const Inspector = require('./Inspector');
const config = require('./config');

const s3Client = new S3Client();

exports.handler = async (event) => {
  const inspector = new Inspector();
  inspector.inspectAll();
  
  // Get input bucket and key from S3 event
  const inputBucket = event.Records[0].s3.bucket.name;
  const inputKey = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  const filename = inputKey.split('/').pop();
  
  // Output bucket from config
  const outputBucket = config.buckets.base;
  const outputKey = config.buckets.stage1 + filename;
  
  try {
    // Download image from S3
    const response = await s3Client.send(new GetObjectCommand({
      Bucket: inputBucket,
      Key: inputKey,
    }));
    
    // Convert stream to buffer
    const chunks = [];
    for await (const chunk of response.Body) {
      chunks.push(chunk);
    }
    const imageBuffer = Buffer.concat(chunks);
    
    // Rotate image 180 degrees
    const rotatedImageBuffer = await sharp(imageBuffer)
      .rotate(180)
      .toBuffer();
    
    // Upload to stage1 bucket
    await s3Client.send(new PutObjectCommand({
      Bucket: outputBucket,
      Key: outputKey,
      Body: rotatedImageBuffer,
      ContentType: response.ContentType || 'image/jpeg',
    }));
    
    // Add metrics
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
