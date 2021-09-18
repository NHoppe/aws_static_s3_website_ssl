# AWS Static S3 website with SSL certificate

This code was created to quickly and easily put a static website online using AWS capabilities (S3, Cloudfront, and ACM). 

## Dependencies

- [AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)
- [Terraform](https://www.terraform.io/downloads.html)
- (Optional) [TFSwitch](https://tfswitch.warrensbox.com/Install/)

## Execution

### Linter
```
make lint
```

Note: To automatically fix the lint errors, you may try to run `make lint_autofix`.

### Terraform Plan<a name="plan"></a>

I abstracted the `terraform plan` command in a `make` target that verifies if the environment variables with the AWS credentials are set. At this time, I assume AWS roles are not in use:
```
make plan
```

### Terraform Apply

The same logic as applies as [Terraform Plan](#plan):
```
make apply
```
