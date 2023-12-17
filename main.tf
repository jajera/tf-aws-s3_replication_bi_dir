variable "use_case" {
  default = "tf-aws-s3_replication"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example-${random_string.suffix.result}"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        },
        {
          "Key": "UseCase",
          "Values": ["${var.use_case}"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name    = "tf-rg-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket" "se1" {
  bucket        = "tf-s3-example-se1-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-example-se1-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket_versioning" "se1" {
  bucket = aws_s3_bucket.se1.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "se2" {
  provider      = aws.southeast2
  bucket        = "tf-s3-example-se2-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-example-se2-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket_versioning" "se2" {
  provider = aws.southeast2
  bucket   = aws_s3_bucket.se2.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "s3_se1_replication" {
  name               = "tf-iam-role-s3_se1_replication-example-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name    = "tf-iam-role-s3_se1_replication-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

data "aws_iam_policy_document" "s3_se1_replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.se1.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.se1.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.se1.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_se1_replication" {
  name   = "tf-iam-policy-s3_se1_replication-example-${random_string.suffix.result}"
  policy = data.aws_iam_policy_document.s3_se1_replication.json
}

resource "aws_iam_role_policy_attachment" "s3_se1_replication" {
  role       = aws_iam_role.s3_se1_replication.name
  policy_arn = aws_iam_policy.s3_se1_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "s3_se1_replication" {

  role   = aws_iam_role.s3_se1_replication.arn
  bucket = aws_s3_bucket.se1.id

  rule {
    id = "rule1"

    filter {
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.se2.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket.se1,
    aws_s3_bucket.se2,
    aws_s3_bucket_versioning.se1,
    aws_s3_bucket_versioning.se2
  ]
}

resource "aws_iam_role" "s3_se2_replication" {
  name               = "tf-iam-role-s3_se2_replication-example-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name    = "tf-iam-role-s3_se2_replication-example-${random_string.suffix.result}"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

data "aws_iam_policy_document" "s3_se2_replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.se2.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.se2.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.se2.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_se2_replication" {
  name   = "tf-iam-policy-s3_se2_replication-example-${random_string.suffix.result}"
  policy = data.aws_iam_policy_document.s3_se2_replication.json
}

resource "aws_iam_role_policy_attachment" "s3_se2_replication" {
  role       = aws_iam_role.s3_se2_replication.name
  policy_arn = aws_iam_policy.s3_se2_replication.arn
}

resource "aws_s3_bucket_replication_configuration" "s3_se2_replication" {
  provider = aws.southeast2
  role     = aws_iam_role.s3_se2_replication.arn
  bucket   = aws_s3_bucket.se2.id

  rule {
    id = "rule1"

    filter {
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.se1.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket.se1,
    aws_s3_bucket.se2,
    aws_s3_bucket_versioning.se1,
    aws_s3_bucket_versioning.se2
  ]
}

resource "null_resource" "copy_sample" {
  # triggers = {
  #   always_run = timestamp()
  # }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp external/sample_se1.jpg  s3://tf-s3-example-se1-${random_string.suffix.result}
      aws s3 cp external/sample_se2.jpg  s3://tf-s3-example-se2-${random_string.suffix.result}
    EOT
  }

  depends_on = [
    aws_s3_bucket_replication_configuration.s3_se1_replication,
    aws_s3_bucket_replication_configuration.s3_se2_replication
  ]
}
