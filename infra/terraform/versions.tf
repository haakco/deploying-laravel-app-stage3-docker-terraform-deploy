terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 2.21"
    }

    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.9"
    }
  }

  required_version = "~> 1.0.0"
}

