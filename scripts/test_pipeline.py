# Test utilities for the document processing pipeline

import json
import boto3
import time
from datetime import datetime

class DocumentProcessorTester:
    def __init__(self, bucket_name, step_function_arn, table_name, region='us-east-1'):
        self.bucket_name = bucket_name
        self.step_function_arn = step_function_arn
        self.table_name = table_name
        self.region = region
        
        # Initialize AWS clients
        self.s3 = boto3.client('s3', region_name=region)
        self.stepfunctions = boto3.client('stepfunctions', region_name=region)
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = self.dynamodb.Table(table_name)
    
    def upload_test_file(self, local_file_path, s3_key=None):
        """Upload a test file to S3"""
        if not s3_key:
            s3_key = f"uploads/test-{int(time.time())}.pdf"
        
        try:
            self.s3.upload_file(local_file_path, self.bucket_name, s3_key)
            print(f"✅ Uploaded {local_file_path} to s3://{self.bucket_name}/{s3_key}")
            return s3_key
        except Exception as e:
            print(f"❌ Failed to upload file: {e}")
            return None
    
    def trigger_processing(self, bucket_key):
        """Manually trigger Step Function processing"""
        input_data = {
            "bucket": self.bucket_name,
            "key": bucket_key
        }
        
        try:
            response = self.stepfunctions.start_execution(
                stateMachineArn=self.step_function_arn,
                input=json.dumps(input_data)
            )
            execution_arn = response['executionArn']
            print(f"✅ Started execution: {execution_arn}")
            return execution_arn
        except Exception as e:
            print(f"❌ Failed to start execution: {e}")
            return None
    
    def check_execution_status(self, execution_arn):
        """Check Step Function execution status"""
        try:
            response = self.stepfunctions.describe_execution(
                executionArn=execution_arn
            )
            status = response['status']
            print(f"📊 Execution status: {status}")
            
            if status in ['SUCCEEDED', 'FAILED', 'TIMED_OUT', 'ABORTED']:
                if 'output' in response:
                    print(f"📄 Output: {response['output']}")
                if 'error' in response:
                    print(f"❌ Error: {response['error']}")
            
            return status
        except Exception as e:
            print(f"❌ Failed to check execution: {e}")
            return None
    
    def wait_for_completion(self, execution_arn, timeout=300):
        """Wait for execution to complete"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            status = self.check_execution_status(execution_arn)
            
            if status in ['SUCCEEDED', 'FAILED', 'TIMED_OUT', 'ABORTED']:
                return status
            
            time.sleep(5)
        
        print(f"⏰ Timeout waiting for execution to complete")
        return 'TIMEOUT'
    
    def check_results(self, limit=10):
        """Check recent processing results in DynamoDB"""
        try:
            response = self.table.scan(
                Limit=limit,
                ProjectionExpression='document_id, processed_date, validation_status, validation_score'
            )
            
            items = response.get('Items', [])
            print(f"📊 Found {len(items)} recent results:")
            
            for item in sorted(items, key=lambda x: x.get('processed_date', ''), reverse=True):
                print(f"  📄 {item.get('document_id', 'Unknown')}: "
                      f"{item.get('validation_status', 'Unknown')} "
                      f"(Score: {item.get('validation_score', 0)})")
            
            return items
        except Exception as e:
            print(f"❌ Failed to check results: {e}")
            return []
    
    def full_test(self, local_file_path):
        """Run a complete end-to-end test"""
        print(f"🧪 Starting full test with {local_file_path}")
        
        # Upload file
        s3_key = self.upload_test_file(local_file_path)
        if not s3_key:
            return False
        
        # Trigger processing
        execution_arn = self.trigger_processing(s3_key)
        if not execution_arn:
            return False
        
        # Wait for completion
        print("⏳ Waiting for processing to complete...")
        final_status = self.wait_for_completion(execution_arn)
        
        if final_status == 'SUCCEEDED':
            print("✅ Processing completed successfully!")
            print("📊 Checking results...")
            self.check_results(5)
            return True
        else:
            print(f"❌ Processing failed with status: {final_status}")
            return False

if __name__ == "__main__":
    # Example usage
    import sys
    
    if len(sys.argv) < 5:
        print("Usage: python test_pipeline.py <bucket_name> <step_function_arn> <table_name> <pdf_file_path>")
        sys.exit(1)
    
    bucket_name = sys.argv[1]
    step_function_arn = sys.argv[2]
    table_name = sys.argv[3]
    pdf_file_path = sys.argv[4]
    
    tester = DocumentProcessorTester(bucket_name, step_function_arn, table_name)
    success = tester.full_test(pdf_file_path)
    
    sys.exit(0 if success else 1)
