![Terraform CI](https://github.com/sebarb/terraform-azurerm-hub-and-spoke-firewall/actions/workflows/terraform-ci.yml/badge.svg)

# Azure Hub and Spoke architecture with Azure Firewall

The project provisions an Azure network infrastructure using Terraform.
The goal of the project is to ensure connectivity to internal web servers through Azure Firewall using DNAT: TCP port 8080 is mapped to port 80 of one VM and port 8081 is mapped to port 80 of the second VM.

The infrastructure includes 3 virtual network in hub-and-spoke topology as follows:
- Hub virtual network which includes two specific subnets: Azure Firewall and Bastion (for administrative purposes)
- two spoke subnets, in each of it there is one Linux based VM which listens to port TCP 80
Both spoke virtual networks are connected to hub using pairing - the easiest vnet interconnection way if no other constraints are requested.

The project is modularized in order to allow as flexibility and reusability.
The network infrastructure is defined through locals mapping.

Connecivity to Vms is allowed only through Bastion, avoiding then any VM port exposure to Internet.
No password hardcoded: managed identity and AADLogin extensions are configured on VMs.
All resources are consistently tagged to support governance and cost tracking

# Architecture

![Architecture](images/topology.png)


```mermaid
graph LR
subgraph hub ["hub 10.0.0.0/16"]
firewall["firewall 192.168.1.0/24"]
bastion["bastion 192.168.0.0/26"]
end

subgraph spoke1 ["10.1.0.0/16"]
subnet-01["subnet-01 10.1.1.0/24"]
end

subgraph spoke2 ["10.2.0.0/16"]
subnet-02["subnet-01 10.2.1.0/24"]

end

hub <== peering ==>spoke1
hub <== peering ==>spoke2
Admin ==>bastion
Internet== (Public_IP:8080/8081) ==>firewall
```


---

# Validation
```bash
curl http://20.86.28.150:8080
Hello from 10.1.1.4
```

![alt text](./images/10114.png)

```bash
curl http://20.86.28.150:8081
Hello from 10.2.1.4
```
![alt text](./images/10214.png)

For administrative purpuse there is Bastion using Entra ID Authentication
Before this, the user should have been assigned with RBAC proper role:

![alt text](./images/rbac_role.png)

Then
Microsoft Entra ID authentication type will show up in Bastion connect:

![alt text](./images/bastion.png)

User connected to the VM is the Entra ID user:

![alt text](./images/login.png)

---

# Features
- Azure Virtual Network
- Multiple subnets
- Network Security Groups on every subnet, restricting traffic to what each tier needs 
- User Defined Routes (UDR)
- Linux VM
- Azure Firewall and firwall rules (DNAT+network rules)
- Azure Bastion
- Consisten resource tagging (application, environment, owner) for governance and cost tracking

---

# Project Structure

```text
.
├── modules
│   ├── bastion  => Creates Bastion with associated public IP
│   ├── compute  => Creates VM
│   ├── network  => Creates network infrastructure
│   ├── firewall => Creates Azure firewall
│   ├── routing  => Create user defined route and subnet associations
│   └── nsg      => Create Network Security Groups for subnets
├── main.tf
├── outputs.tf
├── versions.tf
└── variables.tf


```

---

# Deployment

Initialize Terraform

```bash
terraform init
```

Validate configuration

```bash
terraform validate
```

Generate execution plan

```bash
terraform plan
```

Deploy infrastructure

```bash
terraform apply
```

Destroy infrastructure

```bash
terraform destroy
```

---

# Networking Design

The infrastructure is organized in a hub-and-spoke topology:

- **Hub virtual network** hosts two dedicated subnets: `AzureFirewallSubnet`, running the Azure Firewall instance that centralizes inbound DNAT and inter-spoke traffic inspection, and `AzureBastionSubnet`, running Azure Bastion for administrative access to the VMs.
- **Spoke virtual networks** (spoke-01 and spoke-02) each host a single subnet with one Linux VM running an Apache web server. Neither VM has a public IP.

Both spokes are peered directly with the hub. A User Defined Route sets the spoke subnets' default route (`0.0.0.0/0`) to the Azure Firewall's private IP, so all outbound and inter-spoke traffic is force-tunneled through the firewall for inspection.

Inbound access to the web servers is published through Azure Firewall DNAT rules: TCP 8080 → VM1:80 and TCP 8081 → VM2:80 on the firewall's public IP. Firewall network rules explicitly allow the required traffic between the two spokes.

Each subnet also has its own Network Security Group, providing a second layer of segmentation on top of the UDR/firewall routing: the spoke NSGs allow only HTTP traffic from the firewall's subnet and SSH from the Bastion subnet, while the Bastion subnet NSG follows Azure's required baseline rules for Bastion connectivity.

Administrative access to the VMs is only possible through Bastion (no SSH/RDP exposed to the Internet), and authentication uses Azure AD login via the AADSSHLoginForLinux extension rather than hardcoded credentials.

---

# Learning Objectives

This project demonstrates practical knowledge of:

- Infrastructure as Code (Terraform)
- Azure Virtual Networking
- User Defined Routes
- Azure Firewall
- Linux Virtual Machines
- Cloud-init
- Terraform variables and outputs
- Dynamic subnet creation using `for_each`
- Github Actions CI
- TFLing integration/Checkov integration

---

# Future Improvements

- Azure Monitor & Log Analytics
- Cost dashboard
---

# Terraform Configuration Reference

The following section is automatically generated using **terraform-docs**.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.9.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>4.81.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~>4.3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.81.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./modules/bastion | n/a |
| <a name="module_firewall"></a> [firewall](#module\_firewall) | ./modules/firewall | n/a |
| <a name="module_nsg"></a> [nsg](#module\_nsg) | ./modules/nsg | n/a |
| <a name="module_routing"></a> [routing](#module\_routing) | ./modules/routing | n/a |
| <a name="module_vm"></a> [vm](#module\_vm) | ./modules/compute | n/a |
| <a name="module_vnet"></a> [vnet](#module\_vnet) | ./modules/network | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_public_ip.public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_virtual_network_peering.hub_spokes](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spokes_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [tls_private_key.ssh_private_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | n/a | `string` | n/a | yes |
| <a name="input_environment_name"></a> [environment\_name](#input\_environment\_name) | n/a | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | n/a |
<!-- END_TF_DOCS -->

---

# Author

This project is part of my Azure & Terraform portfolio and demonstrates Azure networking concepts, Infrastructure as Code, and secure network design using Terraform.