# Lambda Test Payloads

This directory contains test payloads for testing individual Lambda functions in the document processing pipeline.

## Available Test Payloads

### 1. `convert_to_image_payload.json`
Tests the PDF to image conversion Lambda function.
- **Input**: S3 bucket, key, and document ID
- **Expected Output**: Array of image references with S3 keys

### 2. `qr_scanner_payload.json`
Tests the QR code scanning Lambda function.
- **Input**: Previous payload + array of converted images
- **Expected Output**: Previous data + detected QR codes

### 3. `ocr_text_payload.json`
Tests the OCR text extraction Lambda function.
- **Input**: Previous payload + QR codes
- **Expected Output**: Previous data + extracted text

### 4. `validator_payload.json`
Tests the data validation Lambda function.
- **Input**: Complete processing data (images, QR codes, text)
- **Expected Output**: Validation results and final status

### 5. `step_function_trigger_payload.json`
Tests the DynamoDB Stream trigger Lambda function.
- **Input**: DynamoDB Stream event (INSERT)
- **Expected Output**: Step Function execution started

## Usage

### PowerShell (Windows)
```powershell
# Test convert to image function
.\scripts\test_lambda.ps1 convert_to_image

# Test QR scanner with custom payload
.\scripts\test_lambda.ps1 qr_scanner test_payloads\qr_scanner_payload.json
```

### Bash (Linux/macOS)
```bash
# Test convert to image function
./scripts/test_lambda.sh convert_to_image

# Test OCR function with custom payload
./scripts/test_lambda.sh ocr_text test_payloads/ocr_text_payload.json
```

## Payload Structure

Each payload follows the Step Function state machine flow:

1. **Initial Input** (from DynamoDB trigger):
   ```json
   {
     "bucket": "s3-bucket-name",
     "key": "uploads/document.pdf",
     "document_id": "unique-doc-id"
   }
   ```

2. **After Convert to Image**:
   ```json
   {
     // Previous data +
     "images": [
       {"page": 1, "s3_key": "processed/doc-id/page_1.png"}
     ]
   }
   ```

3. **After QR Scanning**:
   ```json
   {
     // Previous data +
     "qr_codes": [
       {"page": 1, "data": "QR content", "position": {...}}
     ]
   }
   ```

4. **After OCR**:
   ```json
   {
     // Previous data +
     "extracted_text": [
       {"page": 1, "text": "Extracted text content"}
     ]
   }
   ```

5. **After Validation**:
   ```json
   {
     // All previous data +
     "validation": {
       "status": "valid|invalid",
       "errors": [...],
       "confidence": 0.95
     }
   }
   ```

## Notes

- Replace `document-processor-documents-i6ofs30v` in payloads with your actual S3 bucket name
- Update document IDs and timestamps as needed
- Ensure the specified S3 objects exist when testing functions that read from S3
