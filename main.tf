module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.14.1"
  enabled    = var.enabled
  namespace  = var.namespace
  name       = var.name
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = var.attributes
  tags       = var.tags
}

resource "aws_vpc_peering_connection" "default" {
  count       = var.enabled == "true" ? 1 : 0
  vpc_id      = var.requestor_vpc_id
  peer_vpc_id = var.acceptor_vpc_id

  auto_accept = var.auto_accept

  accepter {
    allow_remote_vpc_dns_resolution = var.acceptor_allow_remote_vpc_dns_resolution
  }

  requester {
    allow_remote_vpc_dns_resolution = var.requestor_allow_remote_vpc_dns_resolution
  }

  tags = module.label.tags

  depends_on = [var.acceptor_cidr_blocks, var.requestor_cidr_blocks]
}

# Create routes from requestor to acceptor
resource "aws_route" "requestor" {
  count = var.enabled == "true" ? var.requestor_route_tables_count * var.acceptor_cidr_blocks_count : 0
  route_table_id = element(
    distinct(sort(var.requestor_route_table_ids)),
    ceil(
      count.index / length(var.acceptor_cidr_blocks),
    ),
  )
  destination_cidr_block    = var.acceptor_cidr_blocks[count.index % length(var.acceptor_cidr_blocks)]
  vpc_peering_connection_id = aws_vpc_peering_connection.default[0].id
  depends_on = [
    aws_vpc_peering_connection.default,
  ]
}

# Create routes from acceptor to requestor
resource "aws_route" "acceptor" {
  count = var.enabled == "true" ? var.acceptor_route_tables_count * var.requestor_cidr_blocks_count : 0
  route_table_id = element(
    distinct(sort(var.acceptor_route_table_ids)),
    ceil(
      count.index / length(var.requestor_cidr_blocks),
    ),
  )
  destination_cidr_block    = var.requestor_cidr_blocks[count.index % length(var.requestor_cidr_blocks)]
  vpc_peering_connection_id = aws_vpc_peering_connection.default[0].id
  depends_on = [
    aws_vpc_peering_connection.default,
  ]
}

