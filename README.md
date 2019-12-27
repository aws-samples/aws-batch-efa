## Sample code to setup NAS Parallel Benchmark using EFA and AWS Batch

This is the sample code for the AWS Batch Blog: Run High Performance Computing Workloads using AWS Batch MultiNode Jobs with Elastic Fabric Adapter

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

# AWS Batch + EFA

To get started, clone this repo locally:

```bash
git clone https://github.com/aws-samples/aws-batch-efa.git
cd aws-batch-efa-blogpost/
```

### AWS Batch Resources

In part 1, we'll create all the necessary AWS Batch resources.

```bash
cd batch-resources/
```

First we'll create a launch template, this launch template installs EFA on the instance and configures the network interface to use EFA. In the `launch_template.json` file substitute `<Account Id>`, `<Security Group>`, `<Subnet Id>` and `<KEY-PAIR-NAME>` with your your information.

Now create the launch template:

```bash
aws ec2 create-launch-template --cli-input-json file://launch_template.json
```

To ensure optimal physical locality of instances, we create a [placement group](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/placement-groups.html#placement-groups-cluster), with strategy `cluster`.

```bash
aws ec2 create-placement-group --group-name "efa" --strategy "cluster" --region [your_region]
```

Next, we'll create the compute environment, this defines the instance type, subnet and IAM role to be used. Edit the `<same-subnet-as-in-LaunchTemplate>` and `<account-id>` sections with the pertinent information. Then create the compute environment:

```bash
aws batch create-compute-environment --cli-input-json file://compute_environment.json
```

Finally we need a job queue to point to the compute environment:

```bash
aws batch create-job-queue --cli-input-json file://job_queue.json
```


### Dockerfile

In part 2, we build the docker image and upload it to Elastic Container Registery (ECR), so we can use it in our job.

```bash
cd ..
pwd # you should be in the aws-batch-efa-blogpost/ directory
```
First we'll build the docker image, to help with this, we included a `Makefile`, simply run:

```bash
make
```

Then you can push the docker image to ECR, first modify the top of the `Makefile` with your region and account id:

```bash
AWS_REGION=[your region]
ACCOUNT_ID=[your account id]
```

Next, push to ECR, note the `Makefile` assumes you have an ECR repo named `aws-batch-efa`:

```bash
make push     # logs in, tags, and pushes to ECR
```

### Job Definition

```bash
cd batch-resources/
```

Now we need a job definition, this defines which docker image to use for the job, edit the `job_definition.json` file and substitute `<ACCOUNT ID>` and `<REGION>`. Then create the job definition:

```
aws batch register-job-definition --cli-input-json file://job_definition.json
{
    "jobDefinitionArn": "arn:aws:batch:us-east-1:<account-id>:job-definition/EFA-MPI-JobDefinition:1",
    "jobDefinitionName": "EFA-MPI-JobDefinition",
    "revision": 1
}
```

### Submit a job

Go back to the main directory:

```bash
cd ..
```

Finally we can submit a job!

```bash
make submit
```

### Credit
* Arya Hezarkhani, Software Development Engineer, AWS Batch
* Jason Rupard, Principal Systems Development Engineer, AWS Batch
* Sean Smith, Software Development Engineer II, AWS HPC
