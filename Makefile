.PHONY: check-aws-env-credentials

check-aws-env-credentials:
	ifndef AWS_ACCESS_KEY_ID
		$(error AWS_ACCESS_KEY_ID is undefined)
	endif
	ifndef AWS_SECRET_ACCESS_KEY
		$(error AWS_ACCESS_KEY_ID is undefined)
	endif

lint:
	terraform fmt -recursive -check -diff

lint_autofix:
	terraform fmt -recursive -write=true

plan: check-aws-env-credentials
	terraform plan

apply: check-aws-env-credentials
	terraform apply
