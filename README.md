# AWS Document Processing Pipeline

A complete AWS-based document processing pipeline that converts PDFs to images, extracts text and QR codes using OCR, validates data, and stores results in DynamoDB.

## Architecture

- **AWS Lambda** (Python 3.12) - Document processing functions
- **AWS Step Functions** - Orchestration
- **S3** - File storage and triggers
- **DynamoDB** - Results storage
- **Terraform** - Infrastructure as Code

## Components

1. **convert_to_image** - Converts PDF pages to PNG images using PyMuPDF
2. **qr_scanner** - Extracts QR code data using pyzbar
3. **ocr_text** - Performs OCR text extraction using pytesseract
4. **validator** - Validates extracted data and stores in DynamoDB

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.12
- PowerShell (for Windows builds)

## Quick Deployment

### Option 1: Automated Deployment (Windows)

```powershell
# Navigate to project directory
cd c:\laragon\www\python\my_text_tract

# Run automated deployment
.\scripts\deploy.ps1
```

### Option 2: Automated Deployment (Linux/macOS)

```bash
# Navigate to project directory
cd /path/to/my_text_tract

# Make scripts executable (first time only)
chmod +x scripts/*.sh

# Run automated deployment
./scripts/deploy.sh
```

### Option 3: Manual Deployment

**Windows:**
```powershell
cd scripts
.\build_layers.ps1
cd ..\terraform
terraform init
terraform plan
terraform apply
```

**Linux/macOS:**
```bash
cd scripts
./build_layers.sh
cd ../terraform
terraform init
terraform plan
terraform apply
```

### Option 4: Plan-Only Mode

**Windows:**
```powershell
.\scripts\deploy.ps1 -PlanOnly
```

**Linux/macOS:**
```bash
./scripts/deploy.sh --plan-only
```

## Testing

1. **Get deployment outputs:**
   ```bash
   cd terraform
   terraform output
   ```

2. **Upload a test PDF:**
   ```bash
   aws s3 cp your-document.pdf s3://YOUR-BUCKET-NAME/uploads/
   ```

3. **Monitor processing:**
   - Check Step Functions console for execution status
   - View results in DynamoDB table

4. **Automated testing:**
   ```bash
   python scripts/test_pipeline.py BUCKET_NAME STEP_FUNCTION_ARN TABLE_NAME path/to/test.pdf
   ```

## Configuration

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and customize:

```hcl
aws_region = "us-east-1"
project_name = "my-document-processor"
environment = "prod"
```

## Event Flow

```
S3 Upload → Step Function → convert_to_image → parallel(qr_scanner, ocr_text) → validator → DynamoDB
```

## Directory Structure

```
document-processor/
├── terraform/           # Infrastructure definitions
│   ├── main.tf         # Main Terraform configuration
│   ├── variables.tf    # Input variables
│   └── outputs.tf      # Output values
├── layers/             # Lambda layers with dependencies
│   ├── common/         # Shared utilities (logging, S3)
│   ├── ocr/           # OCR dependencies (pytesseract, Pillow)
│   └── qr/            # QR scanning dependencies (pyzbar)
├── lambdas/            # Lambda function code
│   ├── convert_to_image/  # PDF to image conversion
│   ├── qr_scanner/        # QR code extraction
│   ├── ocr_text/          # Text extraction via OCR
│   └── validator/         # Data validation and storage
├── scripts/            # Build and deployment scripts
│   ├── build_layers.ps1   # Build Lambda layers
│   ├── deploy.ps1         # Automated deployment
│   ├── cleanup.ps1        # Infrastructure cleanup
│   └── test_pipeline.py   # End-to-end testing
├── .gitignore
└── README.md
```

## Lambda Function Details

### convert_to_image
- **Runtime:** Python 3.12
- **Memory:** 1024 MB
- **Timeout:** 5 minutes
- **Dependencies:** PyMuPDF, Common Layer
- **Function:** Converts PDF pages to high-resolution PNG images

### qr_scanner
- **Runtime:** Python 3.12
- **Memory:** 512 MB
- **Timeout:** 1 minute
- **Dependencies:** pyzbar, Pillow, Common Layer
- **Function:** Detects and decodes QR codes from images

### ocr_text
- **Runtime:** Python 3.12
- **Memory:** 1024 MB
- **Timeout:** 2 minutes
- **Dependencies:** pytesseract, Pillow, Common Layer
- **Function:** Extracts text using OCR with confidence scoring

### validator
- **Runtime:** Python 3.12
- **Memory:** 256 MB
- **Timeout:** 1 minute
- **Dependencies:** boto3, Common Layer
- **Function:** Validates extracted data and stores in DynamoDB

## Step Function Workflow

```json
{
  "Comment": "Document processing pipeline",
  "StartAt": "ConvertToImage",
  "States": {
    "ConvertToImage": {
      "Type": "Task",
      "Next": "ProcessImages"
    },
    "ProcessImages": {
      "Type": "Map",
      "ItemsPath": "$.images",
      "Iterator": {
        "StartAt": "ParallelProcessing",
        "States": {
          "ParallelProcessing": {
            "Type": "Parallel",
            "Branches": [
              {"StartAt": "QRScanner"},
              {"StartAt": "OCRText"}
            ],
            "Next": "Validator"
          }
        }
      }
    }
  }
}
```

## Cleanup

**Windows:**
```powershell
.\scripts\cleanup.ps1
```

**Linux/macOS:**
```bash
./scripts/cleanup.sh
```

Or manually:
```bash
cd terraform
terraform destroy
```

## Troubleshooting

### Common Issues

1. **Layer build fails:**
   - Ensure Python 3.12 is installed
   - Check pip permissions
   - Verify PowerShell execution policy

2. **Terraform apply fails:**
   - Check AWS credentials
   - Verify IAM permissions
   - Ensure unique project name

3. **Lambda timeout:**
   - Check CloudWatch logs
   - Increase memory allocation
   - Optimize image processing

### Monitoring

- **CloudWatch Logs:** `/aws/lambda/PROJECT_NAME-*`
- **Step Functions:** AWS Console → Step Functions
- **DynamoDB:** AWS Console → DynamoDB → Tables

## Cost Optimization

- Use S3 Intelligent Tiering for document storage
- Configure DynamoDB on-demand billing
- Set CloudWatch log retention policies
- Use reserved capacity for high-volume processing

## Security

- All Lambda functions use least-privilege IAM roles
- S3 bucket versioning enabled
- DynamoDB encryption at rest
- VPC configuration available (modify main.tf)

## Scaling

- Step Function map state handles parallel processing
- Lambda auto-scaling based on demand
- DynamoDB auto-scaling configured
- S3 unlimited storage capacity

## Extension Points

- Add virus scanning before processing
- Integrate with AWS Textract for advanced OCR
- Add email notifications via SNS
- Implement document classification
- Add data export to other systems
#   t e x t r a c t 
 
 