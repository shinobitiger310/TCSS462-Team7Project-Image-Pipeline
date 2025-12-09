/**
 * Lambda Function: Zoom Image 50%
 * 
 * Trigger: S3 PUT event on stage1 bucket
 * Input: Image from stage1 bucket
 * Output: Zoomed image to stage2 bucket
 * 
 * SETUP:
 * 1. Update bucket names in config.js
 * 2. Create Lambda function with Node.js 20.x runtime
 * 3. Set timeout to 90 seconds, memory to 1024 MB
 * 4. Add S3 trigger for PUT events on your stage1 bucket
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
  const outputKey = config.buckets.stage2 + filename;
  
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
    
    // Get original dimensions
    const metadata = await sharp(imageBuffer).metadata();
    const originalWidth = metadata.width;
    const originalHeight = metadata.height;
    
    // Calculate crop dimensions (center 50%)
    const cropWidth = Math.round(originalWidth * 0.5);
    const cropHeight = Math.round(originalHeight * 0.5);
    const left = Math.round((originalWidth - cropWidth) / 2);
    const top = Math.round((originalHeight - cropHeight) / 2);
    
    // Crop center and resize back to original dimensions
    const zoomedImageBuffer = await sharp(imageBuffer)
      .extract({ left, top, width: cropWidth, height: cropHeight })
      .resize(originalWidth, originalHeight)
      .toBuffer();
    
    // Upload to stage2 bucket
    await s3Client.send(new PutObjectCommand({
      Bucket: outputBucket,
      Key: outputKey,
      Body: zoomedImageBuffer,
      ContentType: response.ContentType || 'image/jpeg',
    }));
    
    // Add metrics
    inspector.addAttribute('inputBucket', inputBucket);
    inspector.addAttribute('outputBucket', outputBucket);
    inspector.addAttribute('inputKey', inputKey);
    inspector.addAttribute('outputKey', outputKey);
    inspector.addAttribute('message', 'Image zoomed successfully');
    
    inspector.inspectAllDeltas();
    return inspector.finish();
    
  } catch (error) {
    console.error('Error:', error);
    
    inspector.addAttribute('message', 'Error zooming image');
    inspector.addAttribute('error', error.message);
    
    inspector.inspectAllDeltas();
    return inspector.finish();
  }
};
