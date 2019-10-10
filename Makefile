# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# AWS Batch EFA Blogpost
# 1. Edit the AWS_REGION and ACCOUNT_ID parameters
# 2. Run `aws configure` and make sure the region is set the same as here
# 3. make
# 4. make tag
# 5. make push
# 5. when you're happy, submit a job: make submit
# `make push`
# `make submit`

AWS_REGION=?
ACCOUNT_ID=?

all:
  docker build . -t npb

login:
	`aws ecr get-login --no-include-email --region ${AWS_REGION}`

tag:
	docker tag npb:latest ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/aws-batch-efa:latest

push: login tag
	docker push ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/aws-batch-efa:latest

submit:
	aws batch submit-job --region ${AWS_REGION} --job-name example-mpi-job --job-queue EFA-Batch-JobQueue --job-definition EFA-MPI-JobDefinition
