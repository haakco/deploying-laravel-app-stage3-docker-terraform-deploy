terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.1"
    }

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.12"
    }
  }

  required_version = "~> 1.0"
}

