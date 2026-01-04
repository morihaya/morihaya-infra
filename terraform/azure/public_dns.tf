resource "azurerm_dns_zone" "azure-morihaya-tech" {
  name                = "azure.morihaya.tech"
  resource_group_name = azurerm_resource_group.eastus.name

  tags = local.common_tags
}

resource "azurerm_dns_txt_record" "dmarc" {
  name                = "_dmarc"
  zone_name           = azurerm_dns_zone.azure-morihaya-tech.name
  resource_group_name = azurerm_resource_group.eastus.name
  ttl                 = 3600
  record {
    value = "v=DMARC1; p=none"
  }
  tags = local.common_tags
}
