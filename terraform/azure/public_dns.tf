resource "azurerm_dns_zone" "azure-morihaya-tech" {
  name                = "azure.morihaya.tech"
  resource_group_name = azurerm_resource_group.eastus.name

  tags = local.common_tags
}

resource "azurerm_dns_a_record" "dmarc" {
  name                = "_dmarc"
  zone_name           = azurerm_dns_zone.azure-morihaya-tech.name
  resource_group_name = azurerm_resource_group.eastus.name
  ttl                 = 3600
  records             = ["v=DMARC1;p=reject"]
  tags                = local.common_tags
}
