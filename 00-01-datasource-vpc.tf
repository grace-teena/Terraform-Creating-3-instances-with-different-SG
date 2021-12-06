# Fetching Az Names
# ================ #

data "aws_availability_zones" "az" {
    
  state = "available"

}

