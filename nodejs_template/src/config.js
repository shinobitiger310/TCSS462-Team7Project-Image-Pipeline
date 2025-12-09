/**
 * Configuration file for S3 bucket names
 * 
 * IMPORTANT: Replace the bucket names below with your own bucket names
 * before deploying the Lambda functions.
 */

module.exports = {
  buckets: {
    // Bucket where original images are uploaded
    input: process.env.INPUT_BUCKET || 'YOUR-INPUT-BUCKET-NAME',
    
    // Bucket for images after rotate function
    stage1: process.env.STAGE1_BUCKET || 'YOUR-STAGE1-BUCKET-NAME',
    
    // Bucket for images after zoom function
    stage2: process.env.STAGE2_BUCKET || 'YOUR-STAGE2-BUCKET-NAME',
    
    // Bucket for final processed images
    output: process.env.OUTPUT_BUCKET || 'YOUR-OUTPUT-BUCKET-NAME'
  }
};
