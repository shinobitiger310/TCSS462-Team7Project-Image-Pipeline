/**
 * Configuration file for S3 bucket names
 * 
 * IMPORTANT: Replace the bucket names below with your own bucket names
 * before deploying the Lambda functions.
 */

module.exports = {
  buckets: {
    base: 'tcss462-term-project-group-7-js',
    // Bucket where original images are uploaded
    input: process.env.INPUT_BUCKET || '/input',
    
    // Bucket for images after rotate function
    stage1: process.env.STAGE1_BUCKET || '/stage1',
    
    // Bucket for images after zoom function
    stage2: process.env.STAGE2_BUCKET || '/stage2',
    
    // Bucket for final processed images
    output: process.env.OUTPUT_BUCKET || '/output'
  }
};
