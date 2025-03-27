resource "null_resource" "invoke_update_infra_lambda" {
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name UpdateCloudFrontRoute53 /tmp/update_infra_output.json"
  }
  triggers   = { always_run = timestamp() }
  depends_on = [module.lambda]
}

resource "null_resource" "invoke_update_sgs_lambda" {
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name UpdateEC2SecurityGroupFromCloudFrontIPs /tmp/update_sgs_output.json"
  }
  triggers   = { always_run = timestamp() }
  depends_on = [module.lambda]
}
