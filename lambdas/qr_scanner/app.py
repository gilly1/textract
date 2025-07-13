import json
import os
import tempfile
from pyzbar import pyzbar
from PIL import Image
from utils.logger import get_logger
from utils.s3 import S3Client

logger = get_logger(__name__)

def lambda_handler(event, context):
    """
    Extract QR codes from images
    
    Expected event format (from Step Function):
    "image_key_from_convert_step"
    
    Returns:
    {
        "image_key": "path/to/image.png",
        "qr_results": [
            {
                "data": "decoded_text",
                "type": "QRCODE",
                "rect": [x, y, width, height]
            }
        ]
    }
    """
    try:
        # Event is just the image key string from the map iteration
        image_key = event
        
        # Extract bucket from environment or assume same bucket
        bucket = os.environ['BUCKET_NAME']
        
        logger.info(f"Scanning QR codes in image: {bucket}/{image_key}")
        
        s3_client = S3Client()
        
        # Create temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download image
            image_path = os.path.join(temp_dir, 'image.png')
            if not s3_client.download_file(bucket, image_key, image_path):
                raise Exception(f"Failed to download image from {bucket}/{image_key}")
            
            # Open image and scan for QR codes
            image = Image.open(image_path)
            
            # Decode QR codes
            qr_codes = pyzbar.decode(image)
            
            qr_results = []
            for qr_code in qr_codes:
                result = {
                    'data': qr_code.data.decode('utf-8'),
                    'type': qr_code.type,
                    'rect': [qr_code.rect.left, qr_code.rect.top, 
                            qr_code.rect.width, qr_code.rect.height]
                }
                qr_results.append(result)
                logger.info(f"Found QR code: {result['data']}")
            
            logger.info(f"Found {len(qr_results)} QR codes in image")
            
            return {
                'statusCode': 200,
                'image_key': image_key,
                'qr_results': qr_results
            }
            
    except Exception as e:
        logger.error(f"Error scanning QR codes: {str(e)}")
        return {
            'statusCode': 500,
            'image_key': event if isinstance(event, str) else 'unknown',
            'error': str(e),
            'qr_results': []
        }
