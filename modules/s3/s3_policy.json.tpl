{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${bucket_name}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceAccount": "${account_id}"
        }
      }
    }
  ]
}
