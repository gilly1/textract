import boto3
from botocore.exceptions import ClientError
from typing import Optional, Dict, Any
import os
from utils.logger import get_logger

logger = get_logger(__name__)

class S3Client:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        
    def download_file(self, bucket: str, key: str, local_path: str) -> bool:
        """
        Download file from S3 to local path
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            local_path: Local file path to save
            
        Returns:
            True if successful, False otherwise
        """
        try:
            self.s3_client.download_file(bucket, key, local_path)
            logger.info(f"Successfully downloaded {bucket}/{key} to {local_path}")
            return True
        except ClientError as e:
            logger.error(f"Failed to download {bucket}/{key}: {e}")
            return False
    
    def upload_file(self, local_path: str, bucket: str, key: str) -> bool:
        """
        Upload file from local path to S3
        
        Args:
            local_path: Local file path
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            True if successful, False otherwise
        """
        try:
            self.s3_client.upload_file(local_path, bucket, key)
            logger.info(f"Successfully uploaded {local_path} to {bucket}/{key}")
            return True
        except ClientError as e:
            logger.error(f"Failed to upload {local_path} to {bucket}/{key}: {e}")
            return False
    
    def get_object(self, bucket: str, key: str) -> Optional[bytes]:
        """
        Get object content from S3
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            Object content as bytes or None if failed
        """
        try:
            response = self.s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read()
            logger.info(f"Successfully retrieved {bucket}/{key}")
            return content
        except ClientError as e:
            logger.error(f"Failed to get object {bucket}/{key}: {e}")
            return None
    
    def put_object(self, bucket: str, key: str, content: bytes) -> bool:
        """
        Put object content to S3
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            content: Content as bytes
            
        Returns:
            True if successful, False otherwise
        """
        try:
            self.s3_client.put_object(Bucket=bucket, Key=key, Body=content)
            logger.info(f"Successfully put object to {bucket}/{key}")
            return True
        except ClientError as e:
            logger.error(f"Failed to put object to {bucket}/{key}: {e}")
            return False
    
    def list_objects(self, bucket: str, prefix: str = "") -> list:
        """
        List objects in S3 bucket with optional prefix
        
        Args:
            bucket: S3 bucket name
            prefix: Object key prefix
            
        Returns:
            List of object keys
        """
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=bucket,
                Prefix=prefix
            )
            
            if 'Contents' in response:
                keys = [obj['Key'] for obj in response['Contents']]
                logger.info(f"Listed {len(keys)} objects in {bucket} with prefix {prefix}")
                return keys
            else:
                logger.info(f"No objects found in {bucket} with prefix {prefix}")
                return []
                
        except ClientError as e:
            logger.error(f"Failed to list objects in {bucket}: {e}")
            return []
