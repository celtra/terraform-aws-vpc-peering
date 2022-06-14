resource "aws_vpc_peering_connection" "default" {
  count       = module.this.enabled ? 1 : 0
  vpc_id      = var.requestor_vpc_id
  peer_vpc_id = var.acceptor_vpc_id

  auto_accept = var.auto_accept

  accepter {
    allow_remote_vpc_dns_resolution = var.acceptor_allow_remote_vpc_dns_resolution
  }

  requester {
    allow_remote_vpc_dns_resolution = var.requestor_allow_remote_vpc_dns_resolution
  }

  tags = module.this.tags

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }
}

# Create routes from requestor to acceptor
resource "aws_route" "requestor" {
  count                     = module.this.enabled ? var.requestor_route_tables_count * var.acceptor_cidr_blocks_count : 0
  route_table_id            = element(distinct(sort(var.requestor_route_table_ids)), ceil(count.index / length(var.acceptor_cidr_blocks)))
  destination_cidr_block    = var.acceptor_cidr_blocks[count.index % length(var.acceptor_cidr_blocks)]
  vpc_peering_connection_id = join("", aws_vpc_peering_connection.default.*.id)
  depends_on                = [aws_vpc_peering_connection.default]
}

# Create routes from acceptor to requestor
resource "aws_route" "acceptor" {
  count                     = module.this.enabled ? var.acceptor_route_tables_count * var.requestor_cidr_blocks_count : 0
  route_table_id            = element(distinct(sort(var.acceptor_route_table_ids)), ceil(count.index / length(var.requestor_cidr_blocks)))
  destination_cidr_block    = var.requestor_cidr_blocks[count.index % length(var.requestor_cidr_blocks)]
  vpc_peering_connection_id = join("", aws_vpc_peering_connection.default.*.id)
  depends_on                = [aws_vpc_peering_connection.default]
}
