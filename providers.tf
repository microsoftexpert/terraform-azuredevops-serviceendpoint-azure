terraform {
 required_version = ">= 1.12.0"

 required_providers {
 azuredevops = {
 source = "microsoft/azuredevops"
 version = ">= 1.0, < 2.0"
 }
 }
}
