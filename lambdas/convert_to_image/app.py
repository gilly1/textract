import json
import os
import tempfile
from pdf2image import convert_from_path
from utils.logger import get_logger
from utils.s3 import S3Client

logger = get_logger(__name__)

def lambda_handler(event, context):
    """
    Convert PDF pages to PNG images
    
    Expected event format:
    {
        "bucket": "bucket-name",
        "key": "path/to/file.pdf"
    }
    
    Returns:
    {
        "bucket": "bucket-name",
        "key": "original-key",
        "images": ["image1.png", "image2.png", ...]
    }
    """
    try:
        bucket = event['bucket']
        key = event['key']
        
        logger.info(f"Processing PDF: {bucket}/{key}")
        
        s3_client = S3Client()
        
        # Create temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download PDF
            pdf_path = os.path.join(temp_dir, 'input.pdf')
            if not s3_client.download_file(bucket, key, pdf_path):
                raise Exception(f"Failed to download PDF from {bucket}/{key}")
            
            # Convert PDF pages to images using pdf2image
            images = convert_from_path(pdf_path, dpi=200)  # High quality conversion
            image_keys = []
            
            for page_num, image in enumerate(images):
                # Save image locally
                image_filename = f"page_{page_num + 1}.png"
                image_path = os.path.join(temp_dir, image_filename)
                image.save(image_path, 'PNG')
                
                # Upload image to S3
                base_key = key.rsplit('.', 1)[0]  # Remove .pdf extension
                image_key = f"{base_key}/images/{image_filename}"
                
                if s3_client.upload_file(image_path, bucket, image_key):
                    image_keys.append(image_key)
                    logger.info(f"Uploaded image: {bucket}/{image_key}")
                else:
                    logger.error(f"Failed to upload image: {image_key}")
            
            logger.info(f"Successfully converted {len(image_keys)} pages to images")
            
            return {
                'statusCode': 200,
                'bucket': bucket,
                'key': key,
                'images': image_keys
            }
            
    except Exception as e:
        logger.error(f"Error processing PDF: {str(e)}")
        return {
            'statusCode': 500,
            'error': str(e)
        }
