import json
import os
import boto3
from datetime import datetime
import uuid
from utils.logger import get_logger

logger = get_logger(__name__)

def lambda_handler(event, context):
    """
    Validate extracted data and store results in DynamoDB
    
    Expected event format (from Step Function parallel results):
    [
        [
            {
                "statusCode": 200,
                "image_key": "path/to/image.png",
                "qr_results": [...]
            }
        ],
        [
            {
                "statusCode": 200,
                "image_key": "path/to/image.png",
                "text": "extracted_text",
                "confidence": 85.5
            }
        ]
    ]
    
    Returns:
    {
        "statusCode": 200,
        "document_id": "uuid",
        "validation_results": {...}
    }
    """
    try:
        logger.info(f"Validating processing results: {json.dumps(event, default=str)}")
        
        # Parse parallel processing results
        qr_results = event[0][0] if len(event) > 0 and len(event[0]) > 0 else {}
        ocr_results = event[1][0] if len(event) > 1 and len(event[1]) > 0 else {}
        
        # Generate document ID
        document_id = str(uuid.uuid4())
        
        # Perform validation
        validation_results = validate_extraction_data(qr_results, ocr_results)
        
        # Prepare DynamoDB record
        record = {
            'document_id': document_id,
            'processed_date': datetime.utcnow().isoformat(),
            'qr_data': qr_results.get('qr_results', []),
            'ocr_text': ocr_results.get('text', ''),
            'ocr_confidence': ocr_results.get('confidence', 0),
            'validation_status': validation_results['status'],
            'validation_errors': validation_results['errors'],
            'validation_score': validation_results['score']
        }
        
        # Store in DynamoDB
        dynamodb = boto3.resource('dynamodb')
        table_name = os.environ['DYNAMODB_TABLE']
        table = dynamodb.Table(table_name)
        
        table.put_item(Item=record)
        
        logger.info(f"Successfully stored validation results for document: {document_id}")
        
        return {
            'statusCode': 200,
            'document_id': document_id,
            'validation_results': validation_results,
            'stored_record': record
        }
        
    except Exception as e:
        logger.error(f"Error validating data: {str(e)}")
        return {
            'statusCode': 500,
            'error': str(e)
        }

def validate_extraction_data(qr_results, ocr_results):
    """
    Validate the extracted QR and OCR data
    
    Args:
        qr_results: QR scanning results
        ocr_results: OCR text extraction results
    
    Returns:
        Dict with validation status, errors, and score
    """
    errors = []
    score = 0
    
    # Validate QR results
    qr_data = qr_results.get('qr_results', [])
    if qr_data:
        score += 30  # QR codes found
        
        # Check for specific QR data patterns (customize as needed)
        for qr in qr_data:
            if len(qr.get('data', '')) > 10:
                score += 10  # Substantial QR data
    else:
        errors.append("No QR codes detected")
    
    # Validate OCR results
    ocr_text = ocr_results.get('text', '')
    ocr_confidence = ocr_results.get('confidence', 0)
    
    if ocr_text and len(ocr_text.strip()) > 0:
        score += 20  # Text found
        
        if ocr_confidence > 70:
            score += 20  # High confidence
        elif ocr_confidence > 50:
            score += 10  # Medium confidence
        else:
            errors.append(f"Low OCR confidence: {ocr_confidence}%")
            
        # Check for minimum text length
        if len(ocr_text.strip()) > 50:
            score += 10  # Substantial text content
    else:
        errors.append("No text extracted")
    
    # Business logic validation (customize as needed)
    if ocr_text:
        # Example: Check for required fields/patterns
        required_patterns = ['date', 'amount', 'total']
        found_patterns = [pattern for pattern in required_patterns 
                         if pattern.lower() in ocr_text.lower()]
        
        if found_patterns:
            score += len(found_patterns) * 5
        else:
            errors.append("Missing required document patterns")
    
    # Determine overall status
    if score >= 70:
        status = "VALID"
    elif score >= 40:
        status = "WARNING"
    else:
        status = "INVALID"
    
    return {
        'status': status,
        'score': min(score, 100),  # Cap at 100
        'errors': errors,
        'summary': f"Validation completed with {len(errors)} errors"
    }
