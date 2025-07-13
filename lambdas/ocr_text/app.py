import json
import os
import tempfile
import pytesseract
from PIL import Image
from utils.logger import get_logger
from utils.s3 import S3Client

logger = get_logger(__name__)

def lambda_handler(event, context):
    """
    Extract text from images using OCR
    
    Expected event format (from Step Function):
    "image_key_from_convert_step"
    
    Returns:
    {
        "image_key": "path/to/image.png",
        "text": "extracted_text_content",
        "confidence": 85.5
    }
    """
    try:
        # Event is just the image key string from the map iteration
        image_key = event
        
        # Extract bucket from environment
        bucket = os.environ['BUCKET_NAME']
        
        logger.info(f"Performing OCR on image: {bucket}/{image_key}")
        
        s3_client = S3Client()
        
        # Create temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download image
            image_path = os.path.join(temp_dir, 'image.png')
            if not s3_client.download_file(bucket, image_key, image_path):
                raise Exception(f"Failed to download image from {bucket}/{image_key}")
            
            # Open image and perform OCR
            image = Image.open(image_path)
            
            # Configure tesseract for better accuracy
            custom_config = r'--oem 3 --psm 6'
            
            # Extract text
            extracted_text = pytesseract.image_to_string(
                image, 
                config=custom_config
            ).strip()
            
            # Get confidence score
            try:
                data = pytesseract.image_to_data(
                    image, 
                    output_type=pytesseract.Output.DICT,
                    config=custom_config
                )
                confidences = [int(conf) for conf in data['conf'] if int(conf) > 0]
                avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            except:
                avg_confidence = 0
            
            logger.info(f"Extracted text length: {len(extracted_text)}, confidence: {avg_confidence:.1f}%")
            
            return {
                'statusCode': 200,
                'image_key': image_key,
                'text': extracted_text,
                'confidence': round(avg_confidence, 1)
            }
            
    except Exception as e:
        logger.error(f"Error performing OCR: {str(e)}")
        return {
            'statusCode': 500,
            'image_key': event if isinstance(event, str) else 'unknown',
            'error': str(e),
            'text': '',
            'confidence': 0
        }
