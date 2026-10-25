terraform {
  # Use a separate state storage account that already exists. Read the README first.
  # Move the existing local state to the backend. Do not start with empty state.
  backend "azurerm" {}
}
