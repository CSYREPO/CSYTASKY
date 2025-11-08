#!/usr/bin/env bash
set -e

VPC_ID="vpc-0512f926568ea666b"
REGION="us-east-1"

echo "Deleting resources in $VPC_ID ..."

# 1) delete subnets
for subnet in $(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "Subnets[].SubnetId" --output text); do
  echo "Deleting subnet $subnet"
  aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet"
done

# 2) detach & delete internet gateways
for igw in $(aws ec2 describe-internet-gateways --region "$REGION" --filters Name=attachment.vpc-id,Values="$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text); do
  echo "Detaching and deleting IGW $igw"
  aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw" --vpc-id "$VPC_ID"
  aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw"
done

# 3) delete non-main route tables
for rtb in $(aws ec2 describe-route-tables --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "RouteTables[?Associations[0].Main!=true].RouteTableId" --output text); do
  echo "Deleting route table $rtb"
  aws ec2 delete-route-table --region "$REGION" --route-table-id "$rtb"
done

# 4) delete any VPC endpoints
for ep in $(aws ec2 describe-vpc-endpoints --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "VpcEndpoints[].VpcEndpointId" --output text); do
  echo "Deleting VPC endpoint $ep"
  aws ec2 delete-vpc-endpoints --region "$REGION" --vpc-endpoint-ids "$ep"
done

# 5) finally delete the VPC
echo "Deleting VPC $VPC_ID"
aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC_ID"
echo "Done."
