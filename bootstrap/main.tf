
# -----------------------------
# S3 BUCKET FOR PIPELINE ARTIFACTS
# -----------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket = "frontend-artifacts-${random_id.suffix.hex}"

  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

# -----------------------------
# IAM ROLE - CODEPIPELINE
# -----------------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "frontend-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "codebuild:*",
          "iam:PassRole",
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------
# IAM ROLE - CODEBUILD
# -----------------------------
resource "aws_iam_role" "codebuild_role" {
  name = "frontend-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "logs:*",
          "cloudwatch:*",
          "ec2:*",
          "iam:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------
# CODEBUILD PROJECT - INFRA
# -----------------------------
resource "aws_codebuild_project" "infra" {
  name          = "frontend-infra-terraform"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec-infra.yml"
  }
}

# -----------------------------
# CODEBUILD PROJECT - CI (REACT)
# -----------------------------
resource "aws_codebuild_project" "ci" {
  name          = "frontend-react-ci"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-ci.yml"
  }
}

# -----------------------------
# CODEBUILD PROJECT - CLEANUP
# -----------------------------
resource "aws_codebuild_project" "cleanup" {
  name          = "frontend-terraform-destroy"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-destroy.yml"
  }
}

# -----------------------------
# CODEPIPELINE
# -----------------------------
resource "aws_codepipeline" "frontend_pipeline" {
  name     = "frontend-orchestrator"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # SOURCE STAGE
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        Owner      = "lakshmichennur22-lgtm"
        Repo       = "https://github.com/lakshmichennur22-lgtm/codepipeline_hospital.git"
        Branch     = "main"
      }
    }
  }

  # INFRA STAGE
  stage {
    name = "Infra"

    action {
      name            = "Terraform_Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.infra.name
      }
    }
  }

  # CI STAGE
  stage {
    name = "CI"

    action {
      name            = "React_Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      output_artifacts = ["build"]

      configuration = {
        ProjectName = aws_codebuild_project.ci.name
      }
    }
  }

  # CD STAGE
  stage {
    name = "CD"

    action {
      name            = "Deploy_To_S3"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"
      input_artifacts = ["build"]

      configuration = {
        BucketName = "frontend-website-bucket"
        Extract    = "true"
      }
    }
  }

  # MANUAL APPROVAL
  stage {
    name = "Approval"

    action {
      name     = "Manual_Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  # CLEANUP STAGE
  stage {
    name = "Cleanup"

    action {
      name            = "Terraform_Destroy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.cleanup.name
      }
    }
  }
}