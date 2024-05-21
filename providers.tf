# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

## AWS provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.61.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.13.0"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}


provider "aws" {
  region 	= var.region 
}

provider "azurerm" {
   features {}
}

provider "digitalocean" {
  token = var.do_token
}

provider "random" {}
