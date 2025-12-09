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
    input: 'input/',
    
    // Bucket for images after rotate function
    stage1: 'stage1/',
    
    // Bucket for images after zoom function
    stage2: 'stage2/',
    
    // Bucket for final processed images
    output: 'output/'
  }
};
