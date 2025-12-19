.PHONY: init validate build-ubuntu build-windows build-all clean

PACKER_DIR = packer
VARS_FILE = variables.pkrvars.hcl

init:
	cd $(PACKER_DIR) && packer init .

validate:
	cd $(PACKER_DIR) && packer validate -var-file=$(VARS_FILE) .

build-ubuntu:
	cd $(PACKER_DIR) && packer build -var-file=$(VARS_FILE) -only=azure-arm.ubuntu .

build-windows:
	cd $(PACKER_DIR) && packer build -var-file=$(VARS_FILE) -only=azure-arm.windows .

build-ubuntu-gpu:
	cd $(PACKER_DIR) && packer build -var-file=$(VARS_FILE) -var="enable_gpu=true" -only=azure-arm.ubuntu .

build-all:
	cd $(PACKER_DIR) && packer build -var-file=$(VARS_FILE) .

fmt:
	cd $(PACKER_DIR) && packer fmt .

clean:
	rm -rf $(PACKER_DIR)/packer_cache
	rm -f $(PACKER_DIR)/manifest.json
